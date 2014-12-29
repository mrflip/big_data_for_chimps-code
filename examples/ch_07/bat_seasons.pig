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

