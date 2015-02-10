bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

all_stars = LOAD '/data/gold/sports/baseball/allstars.tsv' AS (
  player_id:chararray, year_id:int,
  game_seq:int, game_id:chararray, team_id:chararray, lg_id:chararray, GP: int, starting_pos:int
);

-- Always trim fields we don't need
all_stars_p  = FOREACH all_stars GENERATE player_id, year_id;

-- An outer join of the two will leave both matches and non-matches.
scrub_seasons_join = JOIN
    bat_seasons BY (player_id, year_id) LEFT OUTER,
    all_stars_p BY (player_id, year_id);

-- ...and the non-matches will have Nulls in all the allstars slots
anti_join = FILTER scrub_seasons_join
    BY all_stars_p::player_id IS NULL;

/*
Computing a semi-join with COGROUP
*/
-- Wrong way
bats_g  = JOIN all_stars BY (player_id, year_id), bat_seasons BY (player_id, year_id);
badness = FOREACH bats_g GENERATE bat_seasons::player_id .. bat_seasons::HR;

-- Right way
-- Players with no entry in the allstars_p table have an empty allstars_p bag
all_star_seasons_cg = COGROUP
    bat_seasons BY (player_id, year_id),
    all_stars_p  BY (player_id, year_id);

all_star_seasons = FOREACH 
    (FILTER all_star_seasons_cg BY (COUNT_STAR(all_stars_p) > 0L))
    GENERATE FLATTEN(bat_seasons);


/* COGROUP to anti-join */
bats_ast_cg = COGROUP
    bat_seasons BY (player_id, year_id),
    all_stars_p BY (player_id, year_id);

anti_join = FOREACH
    (FILTER bats_ast_cg BY (COUNT_STAR(all_stars_p) == 0L))
    GENERATE FLATTEN(bat_seasons);

