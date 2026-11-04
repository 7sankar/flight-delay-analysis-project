/*
  =============================================================================
  Script: 03_clean_airlines.sql
  Description: 
    Cleans the 'airlines' lookup table and adds operational status.

  Actions:
    1. Standardizes carrier codes and airline names (Trimming and Uppercasing).
    2. Identifies 'still_operating' status by comparing the last flight date
       to the most recent date in the entire dataset.
  =============================================================================
*/

CREATE OR REPLACE TABLE `airplane-delay-analysis.flight_analysis.airlines_clean` AS
SELECT
  UPPER(TRIM(airline_code)) AS airline_code,
  TRIM(airline)             AS airline,
  flights,
  on_time_arrival_rate,
  cancel_rate,
  first_flight_date,
  last_flight_date,
  -- logic to check if the airlines is still reporting flights in the latest dataset period
  (last_flight_date = (SELECT MAX(last_flight_date) FROM `airplane-delay-analysis.flight_analysis.airlines`)) AS still_operating
FROM `airplane-delay-analysis.flight_analysis.airlines`;