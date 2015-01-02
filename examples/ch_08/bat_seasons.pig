REGISTER /usr/lib/pig/datafu.jar

-- Find distinct tuples based on the 0th (first) key
DEFINE DistinctByYear datafu.pig.bags.DistinctBy('1');

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

bat_seasons = FOREACH bat_seasons GENERATE 
    player_id, 
    year_id, 
    team_id;

player_teams = FOREACH (GROUP bat_seasons BY player_id) {
    sorted = ORDER bat_seasons.(team_id, year_id) BY year_id;
    distinct_by_year = DistinctByYear(sorted);
    GENERATE 
        group AS player_id, 
        BagToString(distinct_by_year, '|');
};

dump @;

/*
(zupcibo01,BOS|1991|BOS|1992|BOS|1993|CHA|1994)
(zuvelpa01,ATL|1982|ATL|1983|ATL|1984|ATL|1985|NYA|1986|NYA|1987|CLE|1988|CLE|1989)
(zuverge01,DET|1954|BAL|1955|BAL|1956|BAL|1957|BAL|1958)
(zwilldu01,CHA|1910|CHF|1914|CHF|1915|CHN|1916)
*/


-- Constructing a Sequence of Sets
sig_seasons = FILTER bat_seasons BY ((year_id >= 1900) AND (lg_id == 'NL' OR lg_id == 'AL') AND (PA >= 450));

y1 = FOREACH sig_seasons GENERATE player_id, team_id, year_id;
y2 = FOREACH sig_seasons GENERATE player_id, team_id, year_id;

-- Put each team of players in context with the next year's team of players
year_to_year_players = COGROUP
    y1 BY (team_id, year_id),
    y2 BY (team_id, year_id-1)
;

-- Clear away the grouped-on fields
rosters = FOREACH year_to_year_players GENERATE
    group.team_id AS team_id,
    group.year_id AS year_id,
    y1.player_id  AS pl1,
    y2.player_id  AS pl2
;

-- The first and last years of existence don't have anything interesting to compare, so reject them.
rosters = FILTER rosters BY (COUNT_STAR(pl1) == 0L OR COUNT_STAR(pl2) == 0L);


-- Set Union and Intersection
DEFINE SetUnion datafu.pig.sets.SetUnion();
DEFINE SetIntersect datafu.pig.sets.SetIntersect();
DEFINE SetDifference datafu.pig.sets.SetDifference();

roster_changes_y2y = FOREACH rosters {
    -- Distinct Union (doesn't need pre-sorting)
    either_year  = SetUnion(pl1, pl2);
    -- The other operations require sorted bags.
    pl1_o = ORDER pl1 BY player_id;
    pl2_o = ORDER pl2 BY player_id;

    -- Set Intersection
    stayed      = SetIntersect(pl1_o, pl2_o);
    -- Set Difference
    y1_departed = SetDifference(pl1_o, pl2_o);
    y2_arrived  = SetDifference(pl2_o, pl1_o);
    -- Symmetric Difference
    non_stayed = SetUnion(y1_departed, y2_arrived);
    -- Set Equality
    is_equal    = ( (COUNT_STAR(non_stayed) == 0L) ? 1 : 0);

    GENERATE 
        year_id, 
        team_id,
        either_year, 
        stayed, 
        y1_departed, 
        y2_arrived, 
        non_stayed, 
        is_equal;
};

DUMP @;
