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

team_yr_parks_g = GROUP park_team_years BY (year_id, team_id);

DESCRIBE team_yr_parks_g;

/*
team_yr_parks_g: {
	group: 
		(
			year_id: long,
			team_id: chararray
		),
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

year_team = FOREACH (GROUP park_team_years BY (year_id, team_id)) GENERATE FLATTEN(group) AS (year_id, team_id);

DESCRIBE year_team

/*
year_team: {
    year_id: long,
    team_id: chararray
}
*/

team_n_parks = FOREACH (GROUP park_team_years BY (team_id,year_id)) GENERATE
    group.team_id, 
    COUNT_STAR(park_team_years) AS n_parks;

DESCRIBE team_n_parks

/*
team_n_parks: {
    team_id: chararray,
    n_parks: long
}
*/

vagabonds = FILTER team_n_parks BY n_parks >= 3;

team_year_w_parks = FOREACH (GROUP park_team_years BY (team_id, year_id)) GENERATE
    group.team_id,
    COUNT_STAR(park_team_years) AS n_parks,
    BagToString(park_team_years.park_id, '^') AS park_ids;
    
DESCRIBE team_year_w_parks;

top_team_year_w_parks = ORDER team_year_w_parks BY n_parks DESC;
-- top_20 = LIMIT top_team_year_w_parks 20; DUMP @;


team_year_w_pkgms = FOREACH (GROUP park_team_years BY (team_id, year_id)) {
    /* Create 'park ID'/'game count' field */
    pty_ordered     = ORDER park_team_years BY n_games DESC;
    pk_ng_pairs     = FOREACH pty_ordered GENERATE
        CONCAT(park_id, ':', (chararray)n_games) AS pk_ng_pair;
        
    /* Generate team/year, number of parks and list of parks/games played */
    GENERATE group.team_id, group.year_id,
        COUNT_STAR(park_teams) AS n_parks,
        BagToString(pk_ng_pairs,'|') AS pk_ngs;
    };
