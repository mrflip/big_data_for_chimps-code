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