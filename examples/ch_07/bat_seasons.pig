bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);


players_PA = FOREACH bat_seasons GENERATE 
    team_id, 
    year_id, 
    player_id, 
    name_first, 
    name_last, 
    PA;

team_playerslist_by_PA = FOREACH (GROUP players_PA BY (team_id, year_id)) {
    players_o_1 = ORDER players_PA BY PA DESC, player_id;
    players_o = LIMIT players_o_1 4;
    GENERATE 
        group.team_id, 
        group.year_id,
        players_o.(player_id, name_first, name_last, PA) AS players_o;
};

team_playerslist_by_PA_2 = FOREACH team_playerslist_by_PA {
    -- will not have same order, even though contents will be identical
    disordered    = DISTINCT players_o;
    -- this ORDER BY does _not_ come for free, though it's not terribly costly
    alt_order     = ORDER players_o BY player_id;
    -- these are all iterative and so will share the same order of descending PA
    still_ordered = FILTER players_o BY PA > 10;
    pa_only       = players_o.PA;
    pretty        = FOREACH players_o GENERATE
        StringConcat((chararray)PA, ':', name_first, ' ', name_last);
    GENERATE 
        team_id, 
        year_id,
        disordered, 
        alt_order,
        still_ordered, 
        pa_only, 
        BagToString(pretty, '|');
};


-- Top 20 Player Seasons by Hits
sorted_seasons = ORDER bat_seasons BY H DESC;
top_20_seasons = LIMIT sorted_seasons 20;


-- Top 5 players per season by RBIs
top_5_per_season = FOREACH (GROUP bat_seasons BY year_id) GENERATE 
    group AS year_id, 
    TOP(5,19,bat_seasons) AS top_5; -- 19th column is RBIs (start at 0)

-- Note - you can achieve the same with:
top_5_per_season = FOREACH (GROUP bat_seasons BY year_id) {
    sorted = ORDER bat_seasons BY RBI DESC;
    top_5 = LIMIT sorted 5;
    ascending = ORDER top_5 BY RBI;
    GENERATE 
        group AS year_id,
        ascending AS top_5;
};


-- Rank records
ranked_seasons = RANK bat_seasons; 
ranked_rbi_seasons = RANK bat_seasons BY 
    RBI DESC, 
    H DESC, 
    player_id;
ranked_hit_dense = RANK bat_seasons BY
    H DESC DENSE;


-- For each season by a player, select the team they played the most games for.
-- In SQL, this is fairly clumsy (involving a self-join and then elimination of
-- ties) In Pig, we can ORDER BY within a foreach and then pluck the first
-- element of the bag.
top_stint_per_player_year = FOREACH (GROUP bat_seasons BY (player_id, year_id)) {
    sorted = ORDER bat_seasons BY RBI DESC;
    top_stint = LIMIT sorted 1;
	stints = COUNT_STAR(bat_seasons);
    GENERATE 
        group.player_id, 
        group.year_id, 
		stints AS stints,
        FLATTEN(top_stint.(team_id, RBI)) AS (team_id, RBI);
};
multiple_stints = FILTER top_stint_per_player_year BY stints > 1;
