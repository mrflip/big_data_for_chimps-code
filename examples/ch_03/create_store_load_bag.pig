park_team_years = LOAD '/data/gold/sports/baseball/park_team_years.tsv' USING PigStorage('\t') AS (
    park_id:chararray, team_id:chararray, year:long, beg_date:chararray, end_date:chararray, n_games:long
);
team_park_seasons = FOREACH (GROUP park_team_years BY team_id) GENERATE 
	group AS team_id, 
	park_team_years.(year, park_id) AS park_years;
	
DESCRIBE team_park_seasons

STORE team_park_seasons INTO './bag_of_park_years.txt';

team_park_seasons = LOAD './bag_of_park_years.txt' AS (
    team_id:chararray,
    park_years: bag{tuple(year:int, park_id:chararray)}
    );

DESCRIBE team_park_seasons
