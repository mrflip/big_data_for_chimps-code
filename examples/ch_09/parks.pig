parks = LOAD '/data/gold/sports/baseball/park-parts-*.tsv' USING PigStorage() AS (
    park_id:chararray,   park_name:chararray,                                       --  $0..$1
    beg_date:chararray,  end_date:chararray, -- not datetime                        --  $2..$3
    is_active:int,       n_games:long,          lng:double,        lat:double,      --  $4..$7
    city:chararray,      state_id:chararray,    country_id:chararray                --  $8..$10
);

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


-- Preparation for Set Operations on Full Tables
main_parks = FILTER parks BY n_games >= 50 AND country_id == 'US';

major_cities = FILTER geonames BY 
    (feature_class == 'P') AND 
    (feature_code matches 'PPL.*') AND 
    (country_code == 'US') AND
    (population > 10000);

bball_city_names = FOREACH main_parks   GENERATE city;
major_city_names = FOREACH major_cities GENERATE name;


-- Distinct Union
major_or_baseball = DISTINCT (UNION bball_city_names, major_city_names);


-- Alternative Distinct Union
REGISTER /usr/lib/pig/datafu.jar
DEFINE FirstTupleFromBag datafu.pig.bags.FirstTupleFromBag();

combined = COGROUP major_cities BY name, main_parks BY city;

major_or_parks = FOREACH combined GENERATE
    group AS city,
    FLATTEN(FirstTupleFromBag(major_cities.(name, population), ((chararray)NULL,(int)NULL))),
    main_parks.park_id AS park_ids;


-- Set Intersection
combined = COGROUP major_cities BY name, main_parks BY city;

major_and_parks_f = FILTER combined BY
    (COUNT_STAR(major_cities) > 0L) AND 
    (COUNT_STAR(main_parks) > 0L);

major_and_parks = FOREACH major_and_parks_f GENERATE
    group AS city,
    FLATTEN(FirstTupleFromBag(major_cities.(state, pop_2011), ((chararray)NULL,(int)NULL))),
    main_parks.park_id AS park_ids;


-- Set Difference
combined = COGROUP major_cities BY name, main_parks BY city;

major_minus_parks_f = FILTER combined BY (COUNT_STAR(main_parks) == 0L);
major_minus_parks   = FOREACH major_minus_parks_f GENERATE
    group AS city,
    FLATTEN(FirstTupleFromBag(major_cities.(name, population), ((chararray)NULL,(int)NULL))),
    main_parks.park_id AS park_ids;

parks_minus_major_f = FILTER combined BY (COUNT_STAR(major_cities) == 0L);
parks_minus_major   = FOREACH parks_minus_major_f GENERATE
    group AS city,
    FLATTEN(FirstTupleFromBag(major_cities.(name, population), ((chararray)NULL,(int)NULL))),
    main_parks.park_id AS park_ids;

difference = UNION major_minus_parks, parks_minus_major;


-- Symetric Set Difference
combined = COGROUP major_cities BY name, main_parks BY city;

major_xor_parks_f = FILTER combined BY
    (COUNT_STAR(major_cities) == 0L) OR (COUNT_STAR(main_parks) == 0L);

major_xor_parks = FOREACH major_xor_parks_f GENERATE
    group AS city,
    FLATTEN(FirstTupleFromBag(major_cities.(name, population), ((chararray)NULL,(int)NULL))),
    main_parks.park_id AS park_ids;


-- Set equality
major_cities_also = FOREACH major_cities GENERATE name;
major_xor_major = FILTER
    (COGROUP major_cities BY name, major_cities_also BY name)
    BY ((COUNT_STAR(major_cities) == 0L) OR (COUNT_STAR(major_cities_also) == 0L));

-- Does not work
major_equals_major_fail = FOREACH (GROUP major_xor_major ALL) GENERATE
    (COUNT_STAR(major_xor_major) == 0L ? 1 : 0) AS is_equal;

-- Does work, using "1\t0" table
one_line = LOAD '/data/gold/one_line.tsv' AS (uno:int, zilch:int);

-- will be `1` (true)
major_equals_major = FOREACH (COGROUP one_line BY 1, major_xor_major BY 1)
    GENERATE (COUNT_STAR(major_xor_major) == 0L ? 1 : 0) AS is_equal;

-- will be `0` (false)
major_equals_parks = FOREACH (COGROUP one_line BY 1, major_xor_parks BY 1)
    GENERATE (COUNT_STAR(major_xor_parks) == 0L ? 1 : 0) AS is_equal;
