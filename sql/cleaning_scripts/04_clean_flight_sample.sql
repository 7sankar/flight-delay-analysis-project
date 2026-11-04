/*
  =============================================================================
  Script: 04_clean_flight_sample.sql
  Description: 
    Cleans the 'flight_sample' table

  Actions:
    1. Standardizes airline and location codes (Trimming and Uppercasing).
    2. Remaps airport codes (e.g., 'DJT' to 'PBI') for both Origin and
       Destination.
    3. Standardizes cancellation data: Explicitly labels reasons as 'NONE'
       or 'Not cancelled' and handles unknown codes.
    4. Handles Nulls for Delay Causes: Converts NULL values in specific
       delay categories (weather, carrier, etc.) to 0.
    5. Adds Derived Analytics: Calculates 'cause_delay_minutes' (total sum of
       specific causes) and an 'is_delayed' flag based on industry standards.
  =============================================================================
*/

CREATE OR REPLACE TABLE `airplane-delay-analysis.flight_analysis.flight_sample_clean` AS
SELECT
  flight_date,
  year,
  month,
  day_of_week,
  UPPER(TRIM(airline_code)) AS airline_code,
  TRIM(airline)             AS airline,
  UPPER(TRIM(tail_number))  AS tail_number,
  flight_number,
  IF(UPPER(TRIM(origin)) = 'DJT', 'PBI', UPPER(TRIM(origin))) AS origin,
  TRIM(origin_city)         AS origin_city,
  UPPER(TRIM(origin_state)) AS origin_state,
  IF(UPPER(TRIM(dest)) = 'DJT', 'PBI', UPPER(TRIM(dest)))     AS dest,
  TRIM(dest_city)           AS dest_city,
  UPPER(TRIM(dest_state))   AS dest_state,

  -- times and delays: NULL for cancelled/diverted flights is meaningful, so kept
  sched_dep_time,
  dep_time,
  dep_delay,
  dep_del15,
  dep_time_block,
  taxi_out,
  taxi_in,
  sched_arr_time,
  arr_time,
  arr_delay,
  arr_del15,
  sched_elapsed_time,
  distance,

  -- status
  COALESCE(cancelled, 0) AS cancelled,
  IF(COALESCE(cancelled, 0) = 1, COALESCE(cancellation_code,   'UNKNOWN'), 'NONE')          AS cancellation_code,
  IF(COALESCE(cancelled, 0) = 1, COALESCE(cancellation_reason, 'Unknown'), 'Not cancelled') AS cancellation_reason,
  COALESCE(diverted, 0)  AS diverted,

  -- delay causes: only recorded when a flight is 15+ min late, so NULL means 0
  COALESCE(carrier_delay, 0)       AS carrier_delay,
  COALESCE(weather_delay, 0)       AS weather_delay,
  COALESCE(nas_delay, 0)           AS nas_delay,
  COALESCE(security_delay, 0)      AS security_delay,
  COALESCE(late_aircraft_delay, 0) AS late_aircraft_delay,

  -- derived
  (COALESCE(carrier_delay, 0) + COALESCE(weather_delay, 0) + COALESCE(nas_delay, 0)
   + COALESCE(security_delay, 0) + COALESCE(late_aircraft_delay, 0)) AS cause_delay_minutes,
  (arr_del15 = 1) AS is_delayed   -- NULL for cancelled/diverted flights
FROM `airplane-delay-analysis.flight_analysis.flight_sample`;
