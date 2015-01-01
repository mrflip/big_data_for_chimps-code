-- Summary of Weight Field
REGISTER /usr/lib/pig/datafu.jar 

people = LOAD '/data/gold/sports/baseball/people.tsv' USING PigStorage('\t') AS (
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

people = FOREACH people GENERATE name_first, name_last, player_id, beg_date, end_date;

by_first_name      = GROUP   people BY name_first;
unique_first_names = FILTER  by_first_name BY COUNT_STAR(people) == 1;
unique_players     = FOREACH unique_first_names GENERATE
    group AS name_first,
    FLATTEN(people.(name_last, player_id, beg_date, end_date));

DUMP @;

/*
...
(Kristopher,Negron,negrokr01,2012-06-07,\N)
(La Schelle,Tarver,tarvela01,1986-07-12,1986-10-05)
(Mysterious,Walker,walkemy01,1910-06-28,1915-09-29)
(Peek-A-Boo,Veach,veachpe01,1884-08-24,1890-07-25)
(Phenomenal,Smith,smithph01,1884-04-18,1891-06-15)
*/