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

players = LOAD '/data/gold/sports/baseball/people.tsv' USING PigStorage('\t') AS (
    player_id:chararray,
    birth_year:int,        birth_month:int,       birth_day: int,
    birth_city:chararray,  birth_state:chararray, birth_country: chararray,
    death_year:int,        death_month:int,       death_day: int,
    death_city:chararray,  death_state:chararray, death_country: chararray,
    name_first:chararray,  name_last:chararray,   name_given:chararray,
    height_in:int,         weight_lb:int,
    bats:chararray,        throws:chararray,
    beg_date:chararray,    end_date:chararray,    college:chararray,
    retro_id:chararray,    bbref_id:chararray
);

-- Filter to only populated places in the US, see http://www.geonames.org/export/codes.html
geonames = FILTER geonames BY feature_code matches 'PPL.*' AND country_code == 'US';
geonames = FOREACH geonames GENERATE geonameid, latitude, longitude, name, admin1_code;

-- Trim extra fields from players, and limit to those born in the USA
players = FILTER players BY birth_country == 'USA';
players = FOREACH players GENERATE player_id, name_first, name_last, birth_city, birth_state, birth_country;

-- Now make our 'approximate' JOIN
geolocated_somewhat = JOIN
    players BY (birth_city, birth_state) LEFT OUTER,
    geonames BY (name, admin1_code)
;

DESCRIBE geolocated_somewhat;

/*
geolocated_somewhat: {
    players::player_id: chararray,
    players::name_first: chararray,
    players::name_last: chararray,
    players::birth_city: chararray,
    players::birth_state: chararray,
    players::birth_country: chararray,
    geonames::geonameid: chararray,
    geonames::latitude: float,
    geonames::longitude: float,
    geonames::name: chararray,
    geonames::admin1_code: chararray}
*/

geolocated_trimmed = FOREACH geolocated_somewhat GENERATE player_id, name_first, name_last, latitude, longitude;

DUMP @;

-- Now lets look at the metrics behind our JOIN
total = FOREACH (GROUP geolocated_trimmed ALL) GENERATE 'total' AS label, COUNT_STAR(geolocated_trimmed) AS total;

with_lat = FILTER geolocated_trimmed BY latitude IS NOT NULL;
with_lat_total = FOREACH (GROUP with_lat ALL) GENERATE 'with_lat' AS label, COUNT_STAR(with_lat) AS total;

without_lat = FILTER geolocated_trimmed BY latitude IS NULL;
without_lat_total = FOREACH (GROUP without_lat ALL) GENERATE 'without_lat' AS label, COUNT_STAR(without_lat) AS total;

report = UNION total, with_lat_total, without_lat_total;

DUMP @;
