-- Summary of Weight Field
REGISTER /usr/lib/pig/datafu.jar

DEFINE Hasher datafu.pig.hash.Hasher('sip24', 'rand');

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

people_hashed = FOREACH people GENERATE Hasher(player_id) AS hash, *;

people_ranked = RANK people_hashed;

-- Back to the original records by skipping the first, hash field
people_shuffled = FOREACH people_ranked GENERATE $2..;

STORE people_shuffled INTO 'people_shuffled/1/';
