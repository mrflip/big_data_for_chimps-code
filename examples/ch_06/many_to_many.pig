bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Count the number of bat_seasons records
total_bat_seasons = FOREACH (GROUP bat_seasons ALL) GENERATE 
    'bat_seasons' AS label,
    COUNT_STAR(bat_seasons) AS total;

park_team_years = LOAD '/data/gold/sports/baseball/park_team_years.tsv' USING PigStorage('\t') AS (
    park_id:chararray, team_id:chararray, year_id:long, beg_date:chararray, end_date:chararray, n_games:long
);

-- Count the number of park_team_years
total_park_team_years = FOREACH (GROUP park_team_years ALL) GENERATE
    'park_team_years' AS label,
    COUNT_STAR(park_team_years) AS total;

-- Always trim the fields we don't need
player_team_years = FOREACH bat_seasons GENERATE year_id, team_id, player_id;
park_team_years   = FOREACH park_team_years GENERATE year_id, team_id, park_id;

player_stadia = FOREACH (JOIN
    player_team_years BY (year_id, team_id),
    park_team_years   BY (year_id, team_id)
    ) GENERATE
        player_team_years::year_id AS year_id, 
        player_team_years::team_id AS team_id,
        player_id,
        park_id;
total_player_stadia = FOREACH (GROUP player_stadia ALL) GENERATE
    'player_stadium' AS label,
    COUNT_STAR(player_stadia) AS total;

-- Finally, UNION our label/totals and dump them together
answer = UNION total_bat_seasons, total_park_team_years, total_player_stadia; DUMP @;

