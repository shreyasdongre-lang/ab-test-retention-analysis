/* =========================================================
   02_load_data.sql
   Purpose: Load cookie_cats.csv into SQL Server.
   NOTE: retention_1 / retention_7 arrive as text ("True"/"False"),
         so we stage the raw load, then cast into the typed table.
   Update the file path below to match where you saved the CSV.
   ========================================================= */

USE CookieCatsABTest;
GO

IF OBJECT_ID('dbo.game_events_staging', 'U') IS NOT NULL
    DROP TABLE dbo.game_events_staging;
GO

CREATE TABLE dbo.game_events_staging (
    userid          INT             NULL,
    version         VARCHAR(10)     NULL,
    sum_gamerounds  INT             NULL,
    retention_1     VARCHAR(10)     NULL,
    retention_7     VARCHAR(10)     NULL
);
GO

-- Adjust the path to wherever cookie_cats.csv lives on your machine
BULK INSERT dbo.game_events_staging
FROM 'C:\path\to\data\cookie_cats.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

TRUNCATE TABLE dbo.game_events;
GO

INSERT INTO dbo.game_events (userid, version, sum_gamerounds, retention_1, retention_7)
SELECT
    userid,
    version,
    sum_gamerounds,
    CASE WHEN retention_1 = 'True' THEN 1 ELSE 0 END,
    CASE WHEN retention_7 = 'True' THEN 1 ELSE 0 END
FROM dbo.game_events_staging;
GO

-- Sanity check
SELECT COUNT(*) AS total_rows FROM dbo.game_events;
SELECT version, COUNT(*) AS players FROM dbo.game_events GROUP BY version;
GO
