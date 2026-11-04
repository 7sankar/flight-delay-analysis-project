/*
============================================================================
Analysis #1
  1. For each airport, compute the share of departures 15+ min late and the 
     average departure delay, weighting each day by flights that actually
     operated.
  2. Keep only airports with enough volume for a fair ranking.
============================================================================
*/

SELECT
  s.airport,
  a.city_name,
  SUM(s.departures_scheduled) AS scheduled_flights,
  ROUND(SAFE_DIVIDE(
    SUM(s.dep_del15_rate * (s.departures_scheduled - s.cancelled)),
    SUM(IF(s.dep_del15_rate IS NOT NULL, s.departures_scheduled - s.cancelled, 0))), 4) AS dep_delay_rate,
  ROUND(SAFE_DIVIDE(
    SUM(s.dep_delay_mean * (s.departures_scheduled - s.cancelled)),
    SUM(IF(s.dep_delay_mean IS NOT NULL, s.departures_scheduled - s.cancelled, 0))), 1) AS avg_dep_delay_min
FROM flight_analysis.daily_airport_stats_clean s
LEFT JOIN flight_analysis.airports_clean a ON s.airport = a.iata_code
GROUP BY s.airport, a.city_name
HAVING SUM(s.departures_scheduled) >= 10000
ORDER BY dep_delay_rate DESC
LIMIT 20;

/*
============================================================================
Analysis #2
  1. For each airline, compute the share of completed flights arriving 15+ min late
     and the median arrival delay (median, since a few huge delays skew averages).
  2. Report the cancel rate separately.
  3. Keep only airlines with enough sample flights.
============================================================================
*/

SELECT
  airline_code,
  airline,
  COUNT(*) AS sample_flights,
  ROUND(AVG(IF(cancelled = 0 AND diverted = 0, arr_del15, NULL)), 4) AS arr_delay_rate,
  ROUND(APPROX_QUANTILES(IF(cancelled = 0 AND diverted = 0, arr_delay, NULL), 100)[OFFSET(50)], 1) AS median_arr_delay_min,
  ROUND(AVG(cancelled), 4) AS cancel_rate
FROM flight_analysis.flight_sample_clean
GROUP BY airline_code, airline
HAVING COUNT(*) >= 1000
ORDER BY arr_delay_rate DESC;

/*
============================================================================
Analysis #3
  1. The baseline delay rate.
  2. Overall share of departures 15+ min late, for context on the airport ranking.
============================================================================
*/

SELECT
  ROUND(SAFE_DIVIDE(
    SUM(dep_del15_rate * (departures_scheduled - cancelled)),
    SUM(IF(dep_del15_rate IS NOT NULL, departures_scheduled - cancelled, 0))), 4) AS overall_dep_delay_rate
FROM flight_analysis.daily_airport_stats_clean;

/*
============================================================================
Analysis #4
  1. The delay rate by month.
  2. Keep year and month separate: Jan-Aug appear in both years, Sep-Dec only in 2025.
============================================================================
*/

SELECT
  EXTRACT(YEAR FROM flight_date)  AS yr,
  EXTRACT(MONTH FROM flight_date) AS mo,
  SUM(departures_scheduled) AS scheduled_flights,
  ROUND(SAFE_DIVIDE(
    SUM(dep_del15_rate * (departures_scheduled - cancelled)),
    SUM(IF(dep_del15_rate IS NOT NULL, departures_scheduled - cancelled, 0))), 4) AS dep_delay_rate,
  ROUND(SUM(cancelled) / SUM(departures_scheduled), 4) AS cancel_rate
FROM flight_analysis.daily_airport_stats_clean
GROUP BY yr, mo
ORDER BY yr, mo;

/*
============================================================================
Analysis #5
  1. Delay causes by month.
  2. Sum each cause's delay minutes per month.
  3. Show minutes of delay per scheduled flight, and each cause's 
     share of the total.
============================================================================
*/

WITH m AS (
  SELECT
    FORMAT_DATE('%Y-%m', flight_date) AS ym,
    SUM(departures_scheduled)         AS flights,
    SUM(weather_delay_minutes)        AS weather,
    SUM(nas_delay_minutes)            AS nas,
    SUM(carrier_delay_minutes)        AS carrier,
    SUM(late_aircraft_delay_minutes)  AS late_aircraft
  FROM flight_analysis.daily_airport_stats_clean
  GROUP BY ym
)
SELECT
  ym,
  ROUND((weather + nas + carrier + late_aircraft) / flights, 2) AS delay_min_per_flight,
  ROUND(weather       / (weather + nas + carrier + late_aircraft), 3) AS weather_share,
  ROUND(nas           / (weather + nas + carrier + late_aircraft), 3) AS nas_share,
  ROUND(carrier       / (weather + nas + carrier + late_aircraft), 3) AS carrier_share,
  ROUND(late_aircraft / (weather + nas + carrier + late_aircraft), 3) AS late_aircraft_share
FROM m
ORDER BY ym;

/*
============================================================================
Analysis #6
  1. Group flights by scheduled departure hour.
  2. Compute the 15+ min arrival delay rate for completed flights.
  3. Compute the late-aircraft share of total delay minutes.
============================================================================
*/

SELECT
  MOD(DIV(sched_dep_time, 100), 24) AS sched_hour,
  COUNT(*) AS flights,
  ROUND(AVG(IF(cancelled = 0 AND diverted = 0, arr_del15, NULL)), 4) AS arr_delay_rate,
  ROUND(SAFE_DIVIDE(
    SUM(late_aircraft_delay),
    SUM(carrier_delay + weather_delay + nas_delay + security_delay + late_aircraft_delay)), 3) AS late_aircraft_share
FROM flight_analysis.flight_sample_clean
GROUP BY sched_hour
ORDER BY sched_hour;