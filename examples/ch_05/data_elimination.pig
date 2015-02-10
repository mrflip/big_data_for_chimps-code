games = LOAD '/data/gold/sports/baseball/games.tsv.bz2' AS (
    game_id:chararray,      year_id:int,
    away_team_id:chararray, home_team_id:chararray,
    away_runs_ct:int,       home_runs_ct:int
);

-- Reducing the fields from 6 to 4
game_scores = FOREACH games GENERATE 
    away_team_id, home_team_id, home_runs_ct, away_runs_ct;

-- Renaming and re-ordering fields
games_a = FOREACH games GENERATE
    year_id, 
    home_team_id AS team,
    home_runs_ct AS runs_for, 
    away_runs_ct AS runs_against, 
    1 AS is_home:int;

games_b = FOREACH games GENERATE
    year_id,
    away_team_id AS team,     
    away_runs_ct AS runs_for, 
    home_runs_ct AS runs_against, 
    0 AS is_home:int;

team_scores = UNION games_a, games_b;

DESCRIBE team_scores

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Sample Data
some_seasons_samp = SAMPLE bat_seasons 0.10;

-- Extract a consistent sample
some_seasons  = FILTER bat_seasons BY (SUBSTRING(player_id, 0, 1) == 's');

-- Selecting 25 arbitrary records
some_players = LIMIT bat_seasons 25;


