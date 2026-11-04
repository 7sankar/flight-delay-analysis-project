/*
============================================================================
Check #1: Months
  1. Calculate the share of sample flights that fall in each month.
  2. Compare it with the share of all real flights in that month.
============================================================================
*/

WITH s AS (
  SELECT FORMAT_DATE('%Y-%m', flight_date) AS ym, COUNT(*) AS n
  FROM flight_analysis.flight_sample_clean GROUP BY ym),
p AS (
  SELECT FORMAT_DATE('%Y-%m', flight_date) AS ym, SUM(departures_scheduled) AS n
  FROM flight_analysis.daily_airport_stats_clean GROUP BY ym)
SELECT p.ym,
       ROUND(s.n / SUM(s.n) OVER (), 4) AS sample_share,
       ROUND(p.n / SUM(p.n) OVER (), 4) AS population_share
FROM p LEFT JOIN s USING (ym)
ORDER BY p.ym;

/*
============================================================================
Check #2: Airlines
  1. Calculate each airline's share of the sample flights.
  2. Compare it with that airline's share of all real flights 
     (airlines table).
============================================================================
*/

WITH s AS (
  SELECT airline_code, COUNT(*) AS n
  FROM flight_analysis.flight_sample_clean GROUP BY airline_code)
SELECT p.airline_code,
       ROUND(s.n / SUM(s.n) OVER (), 4) AS sample_share,
       ROUND(p.flights / SUM(p.flights) OVER (), 4) AS population_share
FROM flight_analysis.airlines_clean p
LEFT JOIN s USING (airline_code)
ORDER BY population_share DESC;

/*
============================================================================
Check #3: Airports
  1. Calculate each of the 15 busiest airports' share of sample departures.
  2. Compare it with its share of all real scheduled departures.
============================================================================
*/

WITH s AS (
  SELECT origin AS airport, COUNT(*) AS n
  FROM flight_analysis.flight_sample_clean GROUP BY origin),
p AS (
  SELECT airport, SUM(departures_scheduled) AS n
  FROM flight_analysis.daily_airport_stats_clean GROUP BY airport)
SELECT p.airport,
       ROUND(s.n / SUM(s.n) OVER (), 4) AS sample_share,
       ROUND(p.n / SUM(p.n) OVER (), 4) AS population_share
FROM p LEFT JOIN s USING (airport)
ORDER BY p.n DESC
LIMIT 15;

/*
============================================================================
Check #4: Headline rates
  1. Calculate the cancel rate and the 15+ min delay rate in the sample.
  2. Compare them with the real rates from the airlines table
     (population delay rate is an approximation: 1 - weighted on-time rate).
============================================================================
*/

SELECT
  (SELECT AVG(CAST(cancelled AS FLOAT64)) FROM flight_analysis.flight_sample_clean) AS sample_cancel_rate,
  (SELECT SUM(flights * cancel_rate) / SUM(flights) FROM flight_analysis.airlines_clean) AS population_cancel_rate,
  (SELECT AVG(CAST(arr_del15 AS FLOAT64)) FROM flight_analysis.flight_sample_clean
    WHERE cancelled = 0 AND diverted = 0) AS sample_delay_rate,
  (SELECT 1 - SUM(flights * on_time_arrival_rate) / SUM(flights) FROM flight_analysis.airlines_clean) AS population_delay_rate;

/*
============================================================================
Check #5: Daily stats airports exist in airports table
  1. Find any airport code in daily stats that has no match in airports_clean.
============================================================================
*/

SELECT DISTINCT s.airport
FROM flight_analysis.daily_airport_stats_clean s
LEFT JOIN flight_analysis.airports_clean a ON s.airport = a.iata_code
WHERE a.iata_code IS NULL;

/*
============================================================================
Check #6: Flight origins and destinations exist in airports table
  1. Find any origin or dest code in the flights that has no match in airports_clean.
============================================================================
*/

SELECT DISTINCT code
FROM (SELECT origin AS code FROM flight_analysis.flight_sample_clean
      UNION DISTINCT
      SELECT dest FROM flight_analysis.flight_sample_clean) f
LEFT JOIN flight_analysis.airports_clean a ON f.code = a.iata_code
WHERE a.iata_code IS NULL;

/*
============================================================================
Check #7: No duplicate airport-days
  1. Count rows per airport and date; there should be only one each.
  This also confirms that merging DJT into PBI didn't create double rows.
============================================================================
*/

SELECT flight_date, airport, COUNT(*) AS n
FROM flight_analysis.daily_airport_stats_clean
GROUP BY flight_date, airport
HAVING COUNT(*) > 1;

/*
============================================================================
Check #9: No duplicate flights
  1. Count rows sharing the same date, airline, flight number, route and scheduled time.
============================================================================
*/

SELECT flight_date, airline_code, flight_number, origin, dest, sched_dep_time, COUNT(*) AS n
FROM flight_analysis.flight_sample_clean
GROUP BY flight_date, airline_code, flight_number, origin, dest, sched_dep_time
HAVING COUNT(*) > 1;

/*
============================================================================
Check #10: 15-minute flags agree with delay minutes
  1. A flight is flagged 1 exactly when its delay is 15 minutes or more.
============================================================================
*/

SELECT COUNT(*) AS bad_rows
FROM flight_analysis.flight_sample_clean
WHERE (arr_delay IS NOT NULL AND arr_del15 != IF(arr_delay >= 15, 1, 0))
   OR (dep_delay IS NOT NULL AND dep_del15 != IF(dep_delay >= 15, 1, 0));

/*
============================================================================
Check #11: Cancelled flights have no arrival time
  1. A cancelled flight can't have arrived.
============================================================================
*/

SELECT COUNT(*) AS bad_rows
FROM flight_analysis.flight_sample_clean
WHERE cancelled = 1 AND arr_time IS NOT NULL;

/*
============================================================================
Check #12: Sample never has more flights than really existed
  1. For each airport-day, count the sample's flights.
  2. Compare with the real scheduled departures for that airport-day.
============================================================================
*/

SELECT f.flight_date, f.origin,
       COUNT(*) AS sample_flights,
       ANY_VALUE(d.departures_scheduled) AS real_departures
FROM flight_analysis.flight_sample_clean f
JOIN flight_analysis.daily_airport_stats_clean d
  ON f.flight_date = d.flight_date AND f.origin = d.airport
GROUP BY f.flight_date, f.origin
HAVING COUNT(*) > ANY_VALUE(d.departures_scheduled);