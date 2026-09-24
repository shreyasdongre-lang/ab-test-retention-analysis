/* =========================================================
   01_create_database_and_tables.sql
   Purpose: Create the database and base table used to store
            the Cookie Cats A/B test dataset.
   ========================================================= */

IF DB_ID('CookieCatsABTest') IS NULL
BEGIN
    CREATE DATABASE CookieCatsABTest;
END
GO

USE CookieCatsABTest;
GO

IF OBJECT_ID('dbo.game_events', 'U') IS NOT NULL
    DROP TABLE dbo.game_events;
GO

CREATE TABLE dbo.game_events (
    userid          INT             NOT NULL PRIMARY KEY,
    version         VARCHAR(10)     NOT NULL,   -- gate_30 (control) or gate_40 (treatment)
    sum_gamerounds  INT             NOT NULL,   -- rounds played in first 14 days
    retention_1     BIT             NOT NULL,   -- returned on day 1
    retention_7     BIT             NOT NULL    -- returned on day 7
);
GO
