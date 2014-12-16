-- Load data about ball parks and the teams that occupied them
park_team_years = LOAD '/data/gold/sports/baseball/park_team_years.tsv' USING PigStorage('\t') AS (
    park_id:chararray, team_id:chararray, year_id:long, beg_date:chararray, end_date:chararray, n_games:long
);

park_teams_g = GROUP park_team_years BY team_id;

DESCRIBE park_teams_g

/*
park_teams_g: {
    group: chararray,
    park_team_years: {
        (
            park_id: chararray,
            team_id: chararray,
            year_id: long,
            beg_date: chararray,
            end_date: chararray,
            n_games: long
        )
    }
}
*/

team_pkyr_pairs = FOREACH (GROUP park_team_years BY team_id) GENERATE
    group AS team_id, 
    park_team_years.(park_id, year_id) AS park_team_years;

DESCRIBE team_pkyr_pairs;

/* 
team_pkyr_pairs: {
    team_id: chararray,
    park_team_years: {
        (park_id: chararray,year_id: long)
    }
}
*/

team_pkyr_bags = FOREACH (GROUP park_team_years BY team_id) GENERATE
    group AS team_id, 
    park_team_years.park_id AS park_ids, 
    park_team_years.year_id AS park_years;

DESCRIBE team_pkyr_bags;

/* 
team_pkyr_bags: {
    team_id: chararray,
    park_ids: {
        (park_id: chararray)
    },
    park_years: {
        (year_id: long)
    }
}
*/
