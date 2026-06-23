# Core Trading Analytics Engine

---

## Problem Statement

Trading desks handle millions of execution records every day. Risk managers and compliance teams constantly need immediate answers to high-stakes questions under tight deadlines — which portfolio is taking the most capital risk right now, and did any stock price make a dangerous jump between consecutive trades?

Pulling raw data into spreadsheets and calculating manually is too slow during live market conditions. Running basic SELECT and WHERE queries returns raw rows — not ranked, not compared, not actionable.

This engine answers both questions in milliseconds using advanced SQL window functions that push all computation directly into the PostgreSQL engine — the fastest and most scalable place to run it.

---


## Solution Overview

Production-style SQL file, addressing a specific analytical question a trading desk would face in real operations.

The core philosophy is to let the database do the heavy work. Window functions compute across multiple rows simultaneously without collapsing them — giving the support engineer ranked, compared, and aggregated results without a single loop or spreadsheet.

---

## Ranking Financial Risk Exposure

**Business question:** Which trades are taking the most capital risk right now, ranked separately per portfolio manager?

**How it works:** Calculates `volume_units × unit_price` as total monetary exposure per trade, then applies `DENSE_RANK()` partitioned by `portfolio_manager`. This creates independent ranking bubbles — Capital_Alpha's trades are ranked amongst themselves and Omega_Trust's trades are ranked amongst themselves. The two managers' rankings never mix.

**Output:**

| portfolio_manager | execution_id | instrument | total_exposure_value | exposure_rank |
|---|---|---|---|---|
| Capital_Alpha | EX_02 | INFY | 10,668,750.00 | 1 |
| Capital_Alpha | EX_01 | INFY | 5,680,000.00 | 2 |
| Capital_Alpha | EX_04 | TCS | 4,815,000.00 | 3 |
| Omega_Trust | EX_05 | RELI | 19,560,000.00 | 1 |
| Omega_Trust | EX_03 | RELI | 2,940,000.00 | 2 |

Omega_Trust EX_05 at ₹19.56M is the largest single position on the entire desk — immediate triage target for the risk team.

---

## Detecting market data drift and gaps

**Business question:** For each stock, what was the price difference between the most recent trade and the one before it?

**How it works:** A CTE named `linear_price_timeline` adds a `previous_execution_price` column to every row using `LAG(unit_price)` partitioned by instrument and ordered by timestamp. The outer SELECT then calculates the arithmetic difference and classifies it automatically with a CASE statement. The first trade of each instrument correctly returns NULL — there is no previous price to compare against.

**Output:**

| execution_id | instrument | current_price | previous_price | drift | classification |
|---|---|---|---|---|---|
| EX_01 | INFY | 1420.00 | NULL | NULL | FIRST TRADE — NO COMPARISON |
| EX_02 | INFY | 1422.50 | 1420.00 | +2.50 | PRICE INCREASE |
| EX_04 | TCS | 3210.00 | NULL | NULL | FIRST TRADE — NO COMPARISON |
| EX_03 | RELI | 2450.00 | NULL | NULL | FIRST TRADE — NO COMPARISON |
| EX_05 | RELI | 2445.00 | 2450.00 | -5.00 | PRICE DROP — REVIEW REQUIRED |

RELI dropped ₹5 per share between EX_03 and EX_05. With 8,000 units at EX_05 this represents ₹40,000 in value erosion — automatically flagged.

---

##  Summary Report

**Business question:** What is each manager's total book size, what percentage does each trade represent, and what is the running cumulative exposure moving through their positions?

**How it works:** Uses three window functions in a single SELECT — `SUM() OVER (PARTITION BY)` for total book size, division for percentage share, and `SUM() OVER (PARTITION BY ... ORDER BY)` with an ORDER clause to create a running cumulative total.

**Key insight surfaced:** Omega_Trust has 86.93% of their entire capital in a single RELI position — a significant concentration risk that no basic SQL query would surface without window functions.

