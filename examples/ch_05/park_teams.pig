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
        StringConcat(park_id, ':', (chararray)n_games) AS pk_ng_pair;
        
    /* Generate team/year, number of parks and list of parks/games played */
    GENERATE group.team_id, group.year_id,
        COUNT_STAR(park_team_years) AS n_parks,
        BagToString(pk_ng_pairs,'|') AS pk_ngs;
    };
top_team_parks = ORDER team_year_w_pkgms BY n_parks DESC;
-- top_20 = LIMIT top_team_parks 20; DUMP @;
-- STORE top_20 INTO 'park_teams_report';


pktm_city = FOREACH park_team_years GENERATE
    team_id, 
    year_id, 
    park_id, 
    n_games,
    SUBSTRING(park_id, 0,3) AS city;

-- First grouping: stats about each city of residence
pktm_stats = FOREACH (GROUP pktm_city BY (team_id, year_id, city)) {
    pty_ordered   = ORDER   pktm_city BY n_games DESC;
    pk_ct_pairs   = FOREACH pty_ordered GENERATE StringConcat(park_id, ':', (chararray)n_games);
    GENERATE
        group.team_id,
        group.year_id,
        group.city                   AS city,
        COUNT_STAR(pktm_city)        AS n_parks,
        SUM(pktm_city.n_games)       AS n_city_games,
        MAX(pktm_city.n_games)       AS max_in_city,
        BagToString(pk_ct_pairs,'|') AS parks
        ;
};
-- top_parks = ORDER pktm_stats BY n_parks DESC; DUMP @;


farhome_gms = FOREACH (GROUP pktm_stats BY (team_id, year_id)) {
    pty_ordered   = ORDER   pktm_stats BY n_city_games DESC;
    city_pairs    = FOREACH pty_ordered GENERATE CONCAT(city, ':', (chararray)n_city_games);
    n_home_gms    = SUM(pktm_stats.n_city_games);
    n_main_city   = MAX(pktm_stats.n_city_games);
    n_main_park   = MAX(pktm_stats.max_in_city);
    -- a nice trick: a string vs a blank makes it easy to scan the data for patterns:
    is_modern     = (group.year_id >= 1905 ? 'mod' : NULL);
    --
    GENERATE group.team_id, group.year_id,
        is_modern                      AS is_modern,
        n_home_gms                     AS n_home_gms,
        n_home_gms - n_main_city       AS n_farhome_gms,
        n_home_gms - n_main_park       AS n_althome_games,
        COUNT_STAR(pktm_stats)         AS n_cities,
        BagToString(city_pairs,'|')    AS cities,
        BagToString(pktm_stats.parks,'|')    AS parks
        ;
};
farhome_gms = ORDER farhome_gms BY n_cities DESC, n_farhome_gms DESC;
STORE farhome_gms INTO 'json_test' USING JsonStorage();
