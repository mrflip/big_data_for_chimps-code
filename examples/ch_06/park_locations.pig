parks = LOAD '/data/gold/sports/baseball/parks.tsv' AS (
    park_id:chararray,
    park_name:chararray, 
    beg_date:chararray, 
    end_date:chararray, 
    is_active:int, 
    n_games:int, 
    lng:float, 
    lat:float, 
    city:chararray, 
    state:chararray, 
    country:chararray
);

-- GeoNames from geonames.org
geonames = LOAD '/data/gold/geo/US.txt.bz2' AS (
    geonameid:chararray, 
    name:chararray, 
    asciiname:chararray,
    alternatenames:chararray,
    latitude:float,
    longitude:float,
    feature_class:chararray,
    feature_code:chararray,
    country_code:chararray,
    cc2:chararray,
    admin1_code:chararray,
    admin2_code:chararray,
    admin3_code:chararray,
    admin4_code:chararray,
    population:int,
    elevation:int,
    dem:chararray,
    timezone:chararray,
    modification_date:chararray
);
geonames = FILTER geonames BY feature_code == 'STDM';

parks_geonames = JOIN parks BY (park_name, state, country) LEFT OUTER, geonames BY (name, admin1_code, country_code);

DUMP @;
