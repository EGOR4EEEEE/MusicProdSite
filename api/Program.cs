using Microsoft.Data.SqlClient;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();
app.UseCors();

// ── Статические файлы сайта ──────────────────────────────────────────
var webRoot = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), @".."));
app.UseDefaultFiles(new DefaultFilesOptions
{
    FileProvider = new PhysicalFileProvider(webRoot),
    RequestPath  = ""
});
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(webRoot),
    RequestPath  = ""
});

// ── Строка подключения ───────────────────────────────────────────────
var CS = builder.Configuration.GetConnectionString("MusicProd")
         ?? throw new InvalidOperationException("Строка 'MusicProd' не найдена в appsettings.json");

// ── Вспомогательный запрос ───────────────────────────────────────────
async Task<List<Dictionary<string, object?>>> Query(string sql,
    Action<SqlCommand>? addParams = null)
{
    await using var conn = new SqlConnection(CS);
    await conn.OpenAsync();
    await using var cmd  = new SqlCommand(sql, conn);
    addParams?.Invoke(cmd);
    await using var reader = await cmd.ExecuteReaderAsync();
    var rows = new List<Dictionary<string, object?>>();
    while (await reader.ReadAsync())
    {
        var row = new Dictionary<string, object?>();
        for (int i = 0; i < reader.FieldCount; i++)
            row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
        rows.Add(row);
    }
    return rows;
}

// ── GET /api/tariffs ─────────────────────────────────────────────────
app.MapGet("/api/tariffs", async () =>
{
    var rows = await Query(@"
        SELECT t.id, t.slug, t.name, t.description,
               t.price, t.unit, t.icon, t.is_featured,
               STRING_AGG(f.feature_text, '|')
                   WITHIN GROUP (ORDER BY f.sort_order) AS features
        FROM Tariffs t
        LEFT JOIN TariffFeatures f ON f.tariff_id = t.id
        WHERE t.is_active = 1
        GROUP BY t.id, t.slug, t.name, t.description,
                 t.price, t.unit, t.icon, t.is_featured
        ORDER BY t.sort_order");

    var result = rows.Select(r => {
        var raw = r["features"]?.ToString();
        r["features"] = string.IsNullOrEmpty(raw) ? Array.Empty<string>() : raw.Split('|');
        return r;
    });
    return Results.Ok(result);
});

// ── GET /api/engineers ───────────────────────────────────────────────
app.MapGet("/api/engineers", async () =>
{
    var rows = await Query(@"
        SELECT id, name, slug, specialization, experience_years, description
        FROM Engineers WHERE is_active = 1 ORDER BY sort_order");
    return Results.Ok(rows);
});

// ── GET /api/works ───────────────────────────────────────────────────
app.MapGet("/api/works", async () =>
{
    var rows = await Query(@"
        SELECT id, title, artist, genre, audio_url, cover_url
        FROM Works WHERE is_active = 1 ORDER BY sort_order");
    return Results.Ok(rows);
});

// ── GET /api/reviews ─────────────────────────────────────────────────
app.MapGet("/api/reviews", async () =>
{
    var rows = await Query(@"
        SELECT id, author_name, city, rating, review_text,
               CONVERT(varchar(10), review_date, 23) AS review_date
        FROM Reviews WHERE is_approved = 1 ORDER BY review_date DESC");
    return Results.Ok(rows);
});

// ── POST /api/bookings ───────────────────────────────────────────────
app.MapPost("/api/bookings", async (BookingRequest req) =>
{
    if (string.IsNullOrWhiteSpace(req.Name) || string.IsNullOrWhiteSpace(req.Phone))
        return Results.BadRequest(new { error = "Имя и телефон обязательны" });

    int? tariffId = null;
    if (!string.IsNullOrEmpty(req.Tariff))
    {
        var t = await Query("SELECT id FROM Tariffs WHERE slug = @s",
            cmd => cmd.Parameters.AddWithValue("@s", req.Tariff));
        if (t.Count > 0) tariffId = Convert.ToInt32(t[0]["id"]);
    }

    int? engineerId = null;
    if (!string.IsNullOrEmpty(req.Engineer))
    {
        var e = await Query("SELECT id FROM Engineers WHERE slug = @s",
            cmd => cmd.Parameters.AddWithValue("@s", req.Engineer));
        if (e.Count > 0) engineerId = Convert.ToInt32(e[0]["id"]);
    }

    await using var conn = new SqlConnection(CS);
    await conn.OpenAsync();
    await using var cmd = new SqlCommand(@"
        INSERT INTO Bookings
            (client_name, phone, email, tariff_id, engineer_id, session_date, comment)
        VALUES
            (@name, @phone, @email, @tariffId, @engineerId, @date, @comment)", conn);

    cmd.Parameters.AddWithValue("@name",       req.Name);
    cmd.Parameters.AddWithValue("@phone",      req.Phone);
    cmd.Parameters.AddWithValue("@email",      (object?)req.Email    ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@tariffId",   (object?)tariffId     ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@engineerId", (object?)engineerId   ?? DBNull.Value);
    cmd.Parameters.AddWithValue("@date",       string.IsNullOrEmpty(req.Date)
                                                   ? (object)DBNull.Value
                                                   : DateOnly.Parse(req.Date));
    cmd.Parameters.AddWithValue("@comment",    (object?)req.Comment  ?? DBNull.Value);
    await cmd.ExecuteNonQueryAsync();

    return Results.Ok(new { success = true, message = "Заявка принята" });
});

app.Run();

record BookingRequest(
    string? Name,
    string? Phone,
    string? Email,
    string? Tariff,
    string? Engineer,
    string? Date,
    string? Comment
);
