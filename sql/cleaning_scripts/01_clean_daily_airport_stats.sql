/*
  =============================================================================
  Script: 01_clean_daily_airport_stats.sql
  Description:
    Cleans the 'daily_airport_stats' table to create a reliable
    summary of airport performance.

  Actions:
    1. Standardizes airport codes (merging 'DJT' into 'PBI').
    2. Handles missing values (NULLs) by converting them to 0 for counts.
    3. Adds an 'all_cancelled_flag' to identify days with no operations.
    4. Fills any missing cancel_rate from cancelled / departures_scheduled.
  =============================================================================
*/

CREATE OR REPLACE TABLE `airplane-delay-analysis.flight_analysis.daily_airport_stats_clean` AS
SELECT
  flight_date,
  -- merge duplicate airport codes
  IF(UPPER(TRIM(airport)) = 'DJT', 'PBI', UPPER(TRIM(airport))) AS airport,

  -- replace NULLs with 0 for flight counts
  COALESCE(departures_scheduled, 0) AS departures_scheduled,
  COALESCE(cancelled, 0)            AS cancelled,
  COALESCE(diverted, 0)             AS diverted,

  -- no flight actually operated, so delay metrics are not applicable
  (COALESCE(cancelled, 0) >= COALESCE(departures_scheduled, 0)) AS all_cancelled_flag,

  -- keep NULL as they are meaningful if no flights flew
  dep_delay_mean,
  dep_del15_rate,
  arr_del15_rate,

  -- ensure delay minutes are 0 and not NULL
  COALESCE(weather_delay_minutes, 0)       AS weather_delay_minutes,
  COALESCE(nas_delay_minutes, 0)           AS nas_delay_minutes,
  COALESCE(carrier_delay_minutes, 0)       AS carrier_delay_minutes,
  COALESCE(late_aircraft_delay_minutes, 0) AS late_aircraft_delay_minutes,

  -- recalculate cancel rate
  COALESCE(cancel_rate, SAFE_DIVIDE(cancelled, departures_scheduled), 0) AS cancel_rate
FROM `airplane-delay-analysis.flight_analysis.daily_airport_stats`;