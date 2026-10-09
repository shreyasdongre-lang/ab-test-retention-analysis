# Mobile Game A/B Test & Retention Analysis (SQL Server)

## Overview

This project analyzes a real controlled A/B test run inside **Cookie Cats**, a mobile
puzzle game, to evaluate the impact of moving the game's first progression "gate"
from level 30 (control) to level 40 (treatment) on player engagement and retention.

The dataset is real and publicly available on Kaggle ("Mobile Games A/B Testing -
Cookie Cats," originally sourced via DataCamp), covering **90,189 players** who
installed the game while the experiment was running.

This is **not synthetic data** — it reflects real player behavior captured during
a live production experiment, making it a realistic exercise in evaluating a
feature change the way a product analytics team would.

## Live Dashboard

An interactive Tableau dashboard built on top of this analysis is published here:

**[Cookie Cats: Gate Placement A/B Test — Tableau Public](https://public.tableau.com/views/CookieCatsABTest_17902805020120/CookieCatsGatePlacementABTest?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)**

It includes:
- KPI summary (total players, Day-1 and Day-7 retention)
- Retention by test group (gate_30 vs gate_40)
- Retention by engagement bucket
- Distribution of rounds played per player, split by test group

## Data

| Column           | Description                                               |
| ---------------- | --------------------------------------------------------- |
| `userid`         | Unique player ID                                          |
| `version`        | Test group — `gate_30` (control) or `gate_40` (treatment) |
| `sum_gamerounds` | Game rounds played in the first 14 days after install     |
| `retention_1`    | Whether the player returned 1 day after install           |
| `retention_7`    | Whether the player returned 7 days after install          |

One player is a known extreme outlier (49,854 rounds played vs. a typical maximum
near 2,961) and is excluded from average/median engagement calculations to avoid
distorting the results.

## What this project covers

- **Experimentation & A/B testing**: group balance checks, retention comparison
between control and treatment, and a manually computed chi-square significance
test in T-SQL for both Day-1 and Day-7 retention (no built-in stats functions in
SQL Server, so the contingency table and test statistic are built from first principles).
- **Retention analysis**: Day-1 and Day-7 retention rates by test group.
- **Engagement / feature impact**: distribution of game rounds played, "zero
round" (activation failure) players, and engagement broken into buckets to see
how depth of play relates to 7-day retention.
- **Automated reporting**: a reusable view (`vw_RetentionScorecard`) and a
parameterized stored procedure (`usp_EngagementByBucket`) so the same analysis
can be re-run without rewriting queries each time.

## Key finding

Moving the gate from level 30 to level 40 **decreased** retention rather than improving it.

| Metric | gate_30 (control) | gate_40 (treatment) | Chi-square (df = 1) | Result |
|---|---|---|---|---|
| Players | 44,700 | 45,489 | | |
| Day-1 retention | 44.82% | 44.23% | 3.18 | Not significant (below 3.841) |
| Day-7 retention | 19.02% | 18.20% | 10.01 | Significant (above 6.635, p < 0.01) |

The Day-1 dip could be due to chance, but the Day-7 drop is statistically
significant. Moving the gate to level 40 hurts one-week retention, a
counter-intuitive result that shows why a feature change should be tested,
and why statistical significance should be checked, not just the raw
percentage difference.

## Files
   - `01_create_database_and_tables.sql` — database and table setup
   - `02_load_data.sql` — loads `cookie_cats.csv` into SQL Server
   - `03_analysis_queries.sql` — retention, engagement, significance testing (Day-1 and Day-7), view, and stored procedure
   - `cookie_cats.csv` — source dataset

## Tools

SQL Server / T-SQL, Tableau Public
