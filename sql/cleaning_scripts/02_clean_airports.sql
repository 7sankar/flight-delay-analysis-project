/*
  =============================================================================
  Script: 02_clean_airports.sql
  Description: 
    Cleans the 'airports' table.
    
  Actions:
    1. Standardizes IATA/ICAO codes to uppercase.
    2. Separates City and State from a single string.
    3. Handles duplicate entries.
  =============================================================================
*/

CREATE OR REPLACE TABLE `airplane-delay-analysis.flight_analysis.airports_clean` AS
WITH remapped AS (
  SELECT
    IF(UPPER(TRIM(iata_code)) = 'DJT', 'PBI', UPPER(TRIM(iata_code))) AS iata_code,
    UPPER(TRIM(icao_code))   AS icao_code,
    TRIM(airport_name)       AS airport_name,
    -- extract city name by removing the suffix (e.g. "Atlanta, GA" -> "Atlanta")
    TRIM(REGEXP_REPLACE(city, r',\s*[A-Z]{2}$', '')) AS city_name,
    UPPER(TRIM(state))       AS state,
    latitude, longitude, elevation_ft,
    LOWER(TRIM(airport_type)) AS airport_type,
    COALESCE(departures, 0)  AS departures,
    COALESCE(arrivals, 0)    AS arrivals
  FROM `airplane-delay-analysis.flight_analysis.airports`
)
SELECT
  iata_code, icao_code, airport_name, city_name, state,
  latitude, longitude, elevation_ft, airport_type,
  SUM(departures) AS departures,
  SUM(arrivals)   AS arrivals
FROM remapped
GROUP BY iata_code, icao_code, airport_name, city_name, state,
         latitude, longitude, elevation_ft, airport_type;