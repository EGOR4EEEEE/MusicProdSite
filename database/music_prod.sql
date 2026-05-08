-- ============================================================
-- Music Prod — Studio Booking Database
-- SQL Server Management Studio 22 / SQL Server 2017+
-- Encoding: UTF-8   Collation: Cyrillic_General_CI_AS
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'MusicProd')
BEGIN
    ALTER DATABASE MusicProd SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MusicProd;
END
GO

CREATE DATABASE MusicProd
    COLLATE Cyrillic_General_CI_AS;
GO

USE MusicProd;
GO

-- ============================================================
-- ТАБЛИЦЫ
-- ============================================================

-- Звукорежиссёры
CREATE TABLE Engineers (
    id               INT           IDENTITY(1,1) PRIMARY KEY,
    name             NVARCHAR(100) NOT NULL,
    slug             NVARCHAR(50)  NOT NULL UNIQUE,
    specialization   NVARCHAR(150) NOT NULL,
    experience_years INT           NOT NULL,
    description      NVARCHAR(500),
    is_active        BIT           NOT NULL DEFAULT 1,
    sort_order       INT           NOT NULL DEFAULT 0
);
GO

-- Тарифы
CREATE TABLE Tariffs (
    id          INT            IDENTITY(1,1) PRIMARY KEY,
    slug        NVARCHAR(50)   NOT NULL UNIQUE,
    name        NVARCHAR(100)  NOT NULL,
    description NVARCHAR(300),
    price       DECIMAL(10,2)  NOT NULL,
    unit        NVARCHAR(20)   NOT NULL DEFAULT N'час',
    icon        NVARCHAR(50),
    is_featured BIT            NOT NULL DEFAULT 0,
    is_active   BIT            NOT NULL DEFAULT 1,
    sort_order  INT            NOT NULL DEFAULT 0
);
GO

-- Особенности тарифов (bullet-points)
CREATE TABLE TariffFeatures (
    id           INT           IDENTITY(1,1) PRIMARY KEY,
    tariff_id    INT           NOT NULL,
    feature_text NVARCHAR(200) NOT NULL,
    sort_order   INT           NOT NULL DEFAULT 0,
    CONSTRAINT FK_TariffFeatures_Tariffs
        FOREIGN KEY (tariff_id) REFERENCES Tariffs(id) ON DELETE CASCADE
);
GO

-- Заявки на бронирование
CREATE TABLE Bookings (
    id           INT            IDENTITY(1,1) PRIMARY KEY,
    client_name  NVARCHAR(100)  NOT NULL,
    phone        NVARCHAR(20)   NOT NULL,
    email        NVARCHAR(150),
    tariff_id    INT,
    engineer_id  INT,
    session_date DATE,
    comment      NVARCHAR(1000),
    status       NVARCHAR(20)   NOT NULL DEFAULT N'new',
    created_at   DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Bookings_Tariffs   FOREIGN KEY (tariff_id)   REFERENCES Tariffs(id),
    CONSTRAINT FK_Bookings_Engineers FOREIGN KEY (engineer_id) REFERENCES Engineers(id),
    CONSTRAINT CHK_Bookings_Status
        CHECK (status IN (N'new', N'confirmed', N'completed', N'cancelled'))
);
GO

-- Отзывы
CREATE TABLE Reviews (
    id          INT           IDENTITY(1,1) PRIMARY KEY,
    author_name NVARCHAR(100) NOT NULL,
    city        NVARCHAR(100),
    rating      TINYINT       NOT NULL DEFAULT 5,
    review_text NVARCHAR(1000) NOT NULL,
    review_date DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    is_approved BIT           NOT NULL DEFAULT 1,
    CONSTRAINT CHK_Reviews_Rating CHECK (rating BETWEEN 1 AND 5)
);
GO

-- Оборудование
CREATE TABLE Equipment (
    id          INT           IDENTITY(1,1) PRIMARY KEY,
    name        NVARCHAR(100) NOT NULL,
    type        NVARCHAR(100) NOT NULL,
    description NVARCHAR(300),
    icon        NVARCHAR(50),
    is_active   BIT           NOT NULL DEFAULT 1
);
GO

-- Связь звукорежиссёр <-> тариф
CREATE TABLE EngineerTariffs (
    engineer_id INT NOT NULL,
    tariff_id   INT NOT NULL,
    PRIMARY KEY (engineer_id, tariff_id),
    CONSTRAINT FK_ET_Engineer FOREIGN KEY (engineer_id) REFERENCES Engineers(id) ON DELETE CASCADE,
    CONSTRAINT FK_ET_Tariff   FOREIGN KEY (tariff_id)   REFERENCES Tariffs(id)   ON DELETE CASCADE
);
GO

-- ============================================================
-- ИНДЕКСЫ
-- ============================================================
CREATE INDEX IX_Bookings_CreatedAt   ON Bookings(created_at DESC);
CREATE INDEX IX_Bookings_Status      ON Bookings(status);
CREATE INDEX IX_Bookings_SessionDate ON Bookings(session_date);
CREATE INDEX IX_Reviews_Date         ON Reviews(review_date DESC);
GO

-- ============================================================
-- ПРЕДСТАВЛЕНИЯ
-- ============================================================

-- Подробная информация о заявках
CREATE VIEW vw_BookingDetails AS
SELECT
    b.id,
    b.client_name,
    b.phone,
    b.email,
    t.name        AS tariff_name,
    t.price       AS tariff_price,
    t.unit        AS tariff_unit,
    e.name        AS engineer_name,
    b.session_date,
    b.comment,
    b.status,
    b.created_at
FROM Bookings b
LEFT JOIN Tariffs   t ON t.id = b.tariff_id
LEFT JOIN Engineers e ON e.id = b.engineer_id;
GO

-- Статистика бронирований по тарифам
CREATE VIEW vw_TariffStats AS
SELECT
    t.id,
    t.name,
    COUNT(b.id) AS total_bookings,
    SUM(CASE WHEN b.status = N'completed'  THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN b.status = N'confirmed'  THEN 1 ELSE 0 END) AS confirmed,
    SUM(CASE WHEN b.status = N'new'        THEN 1 ELSE 0 END) AS pending
FROM Tariffs t
LEFT JOIN Bookings b ON b.tariff_id = t.id
GROUP BY t.id, t.name;
GO

-- ============================================================
-- НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================================

-- Звукорежиссёры
INSERT INTO Engineers (name, slug, specialization, experience_years, description, sort_order) VALUES
(N'Алексей Громов',    'aleksey', N'Сведение и мастеринг',       12, N'Специализируется на роке, металле и поп-музыке. Работал с несколькими российскими лейблами. Любит «живой» звук и аналоговую обработку.', 1),
(N'Дмитрий Орлов',     'dmitriy', N'Запись вокала и речи',        9, N'Эксперт в записи вокала: от попа до джаза. Работает с начинающими артистами — умеет создать комфортную атмосферу для первой записи.',        2),
(N'Игорь Михайлов',    'igor',    N'Электронная музыка',          7, N'Основной профиль — электронная музыка, хип-хоп и R&B. Отлично владеет Ableton и Logic, создаёт плотный и современный электронный саунд.',  3),
(N'Ольга Вершинина',   'olga',    N'Живые инструменты и джаз',   10, N'Музыкант и звукорежиссёр. Специализируется на классике, джазе и камерной музыке. Тонко чувствует нюансы живого исполнения.',              4);
GO

-- Тарифы
INSERT INTO Tariffs (slug, name, description, price, unit, icon, is_featured, sort_order) VALUES
('vocal',       N'Запись вокала',         N'Запись вокала с живым звуком. Идеально для певцов и рэперов',           1500.00, N'час',  'fa-microphone', 0, 1),
('instruments', N'Запись инструментов',   N'Запись живых инструментов: гитара, бас, клавиши, духовые',              2000.00, N'час',  'fa-guitar',     1, 2),
('mixing',      N'Сведение / Мастеринг', N'Профессиональное сведение и мастеринг вашего материала',                 3000.00, N'трек', 'fa-sliders',    0, 3),
('rent',        N'Аренда студии',         N'Полная аренда студии для репетиций, кастингов или записи',              2500.00, N'час',  'fa-door-open',  0, 4);
GO

-- Особенности тарифов
INSERT INTO TariffFeatures (tariff_id, feature_text, sort_order) VALUES
-- Запись вокала
(1, N'Микрофон Neumann TLM 103',          1),
(1, N'Интерфейс RME Fireface',            2),
(1, N'Акустически изолированная кабина',  3),
(1, N'Помощь звукорежиссёра',             4),
(1, N'Наушники для артиста',              5),
-- Запись инструментов
(2, N'Набор инструментальных микрофонов', 1),
(2, N'DI-бокс, предусилители',            2),
(2, N'Просторный живой зал',              3),
(2, N'Опытный звукорежиссёр',             4),
(2, N'Мониторинг в реальном времени',     5),
-- Сведение / Мастеринг
(3, N'Pro Tools / Logic Pro',             1),
(3, N'Мониторы Yamaha HS8',               2),
(3, N'Plug-ins UAD, Waves',               3),
(3, N'До 2 правок включено',              4),
(3, N'Форматы WAV / MP3',                 5),
-- Аренда студии
(4, N'Полная студия в распоряжении',      1),
(4, N'Весь инвентарь включён',            2),
(4, N'Кухня и зона отдыха',               3),
(4, N'Без звукорежиссёра (опционально)',  4),
(4, N'Скидка от 4 часов',                 5);
GO

-- EngineerTariffs — кто работает с каким тарифом
INSERT INTO EngineerTariffs (engineer_id, tariff_id) VALUES
(1,1),(1,2),(1,3),        -- Алексей: вокал, инструменты, сведение
(2,1),(2,4),              -- Дмитрий: вокал, аренда
(3,1),(3,2),(3,3),(3,4),  -- Игорь: все
(4,2),(4,3),(4,4);        -- Ольга: инструменты, сведение, аренда
GO

-- Отзывы
INSERT INTO Reviews (author_name, city, rating, review_text, review_date) VALUES
(N'Анастасия Лукина',   N'Москва',          5, N'«Записывали дебютный сингл. Алексей создал идеальный звук — именно то, что мы слышали в голове. Студия очень уютная, совсем нет стресса. Уже бронируем следующую сессию!»', '2025-02-12'),
(N'Группа «Восток»',    N'Москва',          5, N'«Пишем здесь уже третий альбом. Команда профессиональная, оборудование топовое, а главное — они реально понимают, какой звук нужен рок-группе. Рекомендую всем!»',         '2025-01-28'),
(N'DJ Phantom',         N'Санкт-Петербург', 5, N'«Сведение и мастеринг сделали за 2 дня. Результат — огонь. Трек звучит профессионально на любых системах. Цена полностью оправдана.»',                                    '2025-01-05'),
(N'MC Север',           N'Москва',          5, N'«Первый раз в студии — честно, боялся. Дмитрий сразу успокоил, объяснил процесс. Вышло намного лучше, чем ожидал. Звук живой и настоящий.»',                              '2024-12-19'),
(N'Trio Latitude',      N'Москва',          5, N'«Записывали джазовое трио живьём. Ольга поймала всю атмосферу — и тепло контрабаса, и дыхание саксофона. Очень редкое умение для студии.»',                               '2024-12-03'),
(N'Виктория Соль',      N'Казань',          4, N'«Хорошая студия, приятные ребята. Единственный минус — загруженное расписание, пришлось ждать неделю. Но результат стоил ожидания.»',                                     '2024-11-14'),
(N'Артём Волков',       N'Москва',          5, N'«Снял студию на весь день под репетицию. Удобно, тихо, всё оборудование работает идеально. Буду арендовать регулярно.»',                                                  '2024-10-29'),
(N'Мария Светлова',     N'Москва',          5, N'«Записали детский хор для рекламы. Команда была очень терпелива с детьми, сделали всё чётко и в срок. Огромное спасибо за профессионализм!»',                             '2024-10-08');
GO

-- Оборудование
INSERT INTO Equipment (name, type, description, icon) VALUES
(N'Neumann TLM 103',     N'Конденсаторный микрофон',  N'Топовый вокальный микрофон с исключительной детальностью',       'fa-microphone'),
(N'Shure SM7B',          N'Динамический микрофон',    N'Легендарный микрофон для вокала и подкастов',                    'fa-microphone-lines'),
(N'AKG C414 XLII',       N'Студийный микрофон',       N'Многопаттерновый конденсаторный микрофон',                       'fa-microphone'),
(N'RME Fireface 802',    N'Аудиоинтерфейс',           N'Профессиональный интерфейс с сверхнизкой задержкой',             'fa-plug'),
(N'Yamaha HS8',          N'Студийные мониторы',       N'Откалиброванный мониторинг для точного сведения',                'fa-volume-high'),
(N'Genelec 8030C',       N'Ближнепольные мониторы',   N'Для детальной работы на ближних расстояниях',                    'fa-volume-low'),
(N'Pro Tools Ultimate',  N'Основная DAW',             N'Индустриальный стандарт для записи и сведения',                  'fa-laptop'),
(N'Logic Pro X',         N'DAW для Mac-сессий',       N'Для работы в экосистеме Apple',                                  'fa-apple'),
(N'UAD Apollo Twin',     N'Интерфейс + DSP',          N'С DSP-обработкой плагинов в реальном времени',                   'fa-sliders'),
(N'Beyerdynamic DT 770', N'Наушники для артистов',    N'Закрытые наушники — мониторинг в вокальной кабине',              'fa-headphones');
GO

PRINT N'======================================================';
PRINT N'База данных MusicProd успешно создана и заполнена.';
PRINT N'======================================================';
GO
