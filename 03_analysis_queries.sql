/* =========================================================
   03_analysis_queries.sql
   Purpose: A/B test evaluation, retention analysis, and
            engagement/feature-impact queries for the
            Cookie Cats gate placement experiment
            (control = gate_30, treatment = gate_40).
   ========================================================= */

USE CookieCatsABTest;
GO

-------------------------------------------------------------
-- 1. Group sizes and randomization sanity check
-------------------------------------------------------------
SELECT
    version,
    COUNT(*)                                   AS players,
    CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER () AS pct_of_total
FROM dbo.game_events
GROUP BY version;
GO

-------------------------------------------------------------
-- 2. Day-1 and Day-7 retention rate by group
-------------------------------------------------------------
SELECT
    version,
    COUNT(*)                                    AS players,
    SUM(CAST(retention_1 AS INT))               AS retained_day1,
    ROUND(AVG(CAST(retention_1 AS FLOAT)) * 100, 2)  AS retention_1_pct,
    SUM(CAST(retention_7 AS INT))               AS retained_day7,
    ROUND(AVG(CAST(retention_7 AS FLOAT)) * 100, 2)  AS retention_7_pct
FROM dbo.game_events
GROUP BY version;
GO

-------------------------------------------------------------
-- 3. Engagement (game rounds played), excluding the known
--    extreme outlier (one player logged 49,854 rounds vs a
--    typical max near ~2,961) so it doesn't skew the average
-------------------------------------------------------------
SELECT
    version,
    COUNT(*)                                     AS players,
    ROUND(AVG(CAST(sum_gamerounds AS FLOAT)), 2) AS avg_rounds,
    MAX(sum_gamerounds)                          AS max_rounds
FROM dbo.game_events
WHERE sum_gamerounds < 49854
GROUP BY version;
GO

-- Median rounds per group (PERCENTILE_CONT)
SELECT DISTINCT
    version,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sum_gamerounds)
        OVER (PARTITION BY version) AS median_rounds
FROM dbo.game_events
WHERE sum_gamerounds < 49854;
GO

-------------------------------------------------------------
-- 4. Players who never played a single round after installing
--    (activation failure -- useful "friction" signal)
-------------------------------------------------------------
SELECT
    version,
    COUNT(*) AS zero_round_players,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY 1), 2) AS pct_of_all_zero_round_players
FROM dbo.game_events
WHERE sum_gamerounds = 0
GROUP BY version;
GO

-------------------------------------------------------------
-- 5. Chi-square test of independence: is the difference in
--    Day-1 retention between gate_30 and gate_40 statistically
--    significant? (manual chi-square, since T-SQL has no
--    built-in significance test)
-------------------------------------------------------------
WITH observed AS (
    SELECT
        version,
        SUM(CAST(retention_1 AS INT))                    AS retained,
        COUNT(*) - SUM(CAST(retention_1 AS INT))          AS not_retained,
        COUNT(*)                                          AS total
    FROM dbo.game_events
    GROUP BY version
),
totals AS (
    SELECT
        SUM(retained)      AS total_retained,
        SUM(not_retained)  AS total_not_retained,
        SUM(total)         AS grand_total
    FROM observed
),
expected AS (
    SELECT
        o.version,
        o.retained, o.not_retained, o.total,
        o.total * (t.total_retained * 1.0 / t.grand_total)     AS exp_retained,
        o.total * (t.total_not_retained * 1.0 / t.grand_total) AS exp_not_retained
    FROM observed o CROSS JOIN totals t
)
SELECT
    SUM(
        SQUARE(retained - exp_retained) / exp_retained +
        SQUARE(not_retained - exp_not_retained) / exp_not_retained
    ) AS chi_square_statistic
    -- df = 1 for a 2x2 table; compare against 3.841 (p < 0.05 critical value)
FROM expected;
GO

-------------------------------------------------------------
-- 6. Reusable view: retention scorecard by test group
-------------------------------------------------------------
IF OBJECT_ID('dbo.vw_RetentionScorecard', 'V') IS NOT NULL
    DROP VIEW dbo.vw_RetentionScorecard;
GO

CREATE VIEW dbo.vw_RetentionScorecard AS
SELECT
    version,
    COUNT(*)                                        AS players,
    ROUND(AVG(CAST(retention_1 AS FLOAT)) * 100, 2)  AS retention_1_pct,
    ROUND(AVG(CAST(retention_7 AS FLOAT)) * 100, 2)  AS retention_7_pct,
    ROUND(AVG(CASE WHEN sum_gamerounds < 49854
                    THEN CAST(sum_gamerounds AS FLOAT) END), 2) AS avg_rounds_played
FROM dbo.game_events
GROUP BY version;
GO

-------------------------------------------------------------
-- 7. Stored procedure: engagement breakdown by rounds-played
--    bucket, for a given test group (feature-impact drilldown)
-------------------------------------------------------------
IF OBJECT_ID('dbo.usp_EngagementByBucket', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_EngagementByBucket;
GO

CREATE PROCEDURE dbo.usp_EngagementByBucket
    @version VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CASE
            WHEN sum_gamerounds = 0                        THEN '0 (never played)'
            WHEN sum_gamerounds BETWEEN 1 AND 10            THEN '1-10'
            WHEN sum_gamerounds BETWEEN 11 AND 50           THEN '11-50'
            WHEN sum_gamerounds BETWEEN 51 AND 200          THEN '51-200'
            ELSE '200+'
        END                                                 AS rounds_bucket,
        COUNT(*)                                            AS players,
        ROUND(AVG(CAST(retention_7 AS FLOAT)) * 100, 2)      AS retention_7_pct
    FROM dbo.game_events
    WHERE version = @version
      AND sum_gamerounds < 49854
    GROUP BY
        CASE
            WHEN sum_gamerounds = 0                        THEN '0 (never played)'
            WHEN sum_gamerounds BETWEEN 1 AND 10            THEN '1-10'
            WHEN sum_gamerounds BETWEEN 11 AND 50           THEN '11-50'
            WHEN sum_gamerounds BETWEEN 51 AND 200          THEN '51-200'
            ELSE '200+'
        END
    ORDER BY MIN(sum_gamerounds);
END
GO

-- Example execution:
-- EXEC dbo.usp_EngagementByBucket @version = 'gate_30';
-- EXEC dbo.usp_EngagementByBucket @version = 'gate_40';
