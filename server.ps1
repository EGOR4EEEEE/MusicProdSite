$port = if ($env:PORT) { [int]$env:PORT } else { 5500 }
$root = "D:\Music Prod update"
$log  = "D:\Music Prod update\server.log"

"[START] port=$port root=$root" | Out-File $log -Encoding UTF8

try {
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://localhost:$port/")
  $listener.Start()
  "[OK] HttpListener started on $port" | Out-File $log -Append
} catch {
  "[ERROR] $_" | Out-File $log -Append
  exit 1
}

[Console]::Out.WriteLine("Serving http://localhost:$port")
[Console]::Out.Flush()

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css'
  '.js'   = 'application/javascript'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.ico'  = 'image/x-icon'
}

while ($listener.IsListening) {
  try {
    $ctx  = $listener.GetContext()
    $req  = $ctx.Request
    $resp = $ctx.Response

    $rel  = $req.Url.AbsolutePath.TrimStart('/')
    if ($rel -eq '') { $rel = 'index.html' }
    $file = Join-Path $root $rel

    if (Test-Path $file -PathType Leaf) {
      $ext  = [IO.Path]::GetExtension($file).ToLower()
      $ct   = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
      $data = [IO.File]::ReadAllBytes($file)
      $resp.ContentType     = $ct
      $resp.ContentLength64 = $data.Length
      $resp.OutputStream.Write($data, 0, $data.Length)
    } else {
      $resp.StatusCode = 404
      $msg = [Text.Encoding]::UTF8.GetBytes("404 Not Found")
      $resp.OutputStream.Write($msg, 0, $msg.Length)
    }
    $resp.OutputStream.Close()
  } catch { }
}
