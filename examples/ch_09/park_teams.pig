-- Load data about ball parks and the teams that occupied them
park_team_years = LOAD '/data/gold/sports/baseball/park_team_years.tsv' USING PigStorage('\t') AS (
    park_id:chararray, team_id:chararray, year_id:long, beg_date:chararray, end_date:chararray, n_games:long
);

-- Eliminating duplicates
many_team_park_pairs = FOREACH park_team_years GENERATE 
    team_id, 
    park_id;
team_park_pairs = DISTINCT many_team_park_pairs;


-- Don't do this!
dont_do_this = FOREACH (GROUP park_team_years BY (team_id, park_id)) GENERATE
    group.team_id, 
    group.park_id;


-- Eliminating Duplicate Records from a Group
team_park_list = FOREACH (GROUP park_team_years BY team_id) {
    parks = DISTINCT park_team_years.park_id;
    GENERATE 
        group AS team_id, 
        BagToString(parks, '|');
};
