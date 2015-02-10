games = LOAD '/data/gold/sports/baseball/games_lite.tsv' AS (
  game_id:chararray,      year_id:int,
  away_team_id:chararray, home_team_id:chararray,
  away_runs_ct:int,       home_runs_ct:int
);

home_wins = FILTER games BY home_runs_ct > away_runs_ct;
STORE home_wins INTO './home_wins.tsv';
