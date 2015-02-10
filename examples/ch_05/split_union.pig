bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Splits can split one relation into multiple relations
SPLIT bat_seasons
  INTO young   IF  age <= 30,
       middle  IF (age >= 30) AND (age < 40),
       old OTHERWISE
;

STORE young  INTO 'young_player_seasons';
STORE middle INTO 'middle_age_player_seasons';
STORE old    INTO 'old_player_seasons';


-- Unions can bring relations with the same schema together
young_player_seasons = LOAD 'young_player_seasons' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);
middle_age_player_seasons = LOAD 'middle_age_player_seasons' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);
old_player_seasons = LOAD 'old_player_seasons' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

young_names = FOREACH young_player_seasons GENERATE player_id, name_first, name_last;
middle_age_names = FOREACH middle_age_player_seasons GENERATE player_id, name_first, name_last;
old_names = FOREACH old_player_seasons GENERATE player_id, name_first, name_last;

all_players = UNION young_names, middle_age_names, old_names;
all_unique_players = DISTINCT all_players;

STORE all_unique_players INTO 'all_unique_players';


-- Unions to symmetrize a relationship
games = LOAD '/data/gold/sports/baseball/games_lite.tsv' AS (
  game_id:chararray,      year_id:int,
  away_team_id:chararray, home_team_id:chararray,
  away_runs_ct:int,       home_runs_ct:int
);

games_a = FOREACH games GENERATE
  year_id, home_team_id AS team,
  home_runs_ct AS runs_for, away_runs_ct AS runs_against, 1 AS is_home:int;

games_b = FOREACH games GENERATE
  year_id, away_team_id AS team,
  away_runs_ct AS runs_for, home_runs_ct AS runs_against, 0 AS is_home:int;

team_scores = UNION games_a, games_b;

STORE team_scores INTO 'team_scores';

DESCRIBE team_scores;
--   team_scores: {team: chararray,year_id: int,runs_for: int,runs_against: int,is_home: int}
