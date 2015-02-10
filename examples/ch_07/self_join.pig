bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- First lets figure how big a team is
players_per_team = FOREACH (
    GROUP bat_seasons BY (team_id, year_id)) 
    GENERATE 
        FLATTEN(group) AS (team_id, year_id), 
        COUNT_STAR(bat_seasons) AS total_players;
avg_players = FOREACH (GROUP players_per_team ALL) GENERATE 
    AVG(players_per_team.total_players) AS avg_players;
DUMP avg_players;

-- Now lets do our self-join to get teammate pairs
p1 = FOREACH bat_seasons GENERATE player_id, team_id, year_id;
p2 = FOREACH bat_seasons GENERATE player_id, team_id, year_id;

teammate_pairs = FOREACH (JOIN
    p1 BY (team_id, year_id),
    p2 by (team_id, year_id)
    ) GENERATE
        p1::player_id AS pl1,
        p2::player_id AS pl2;

teammate_pairs = FILTER teammate_pairs BY (pl1 != pl2);

-- Finally: how big is our join?
total_teammate_pairs = FOREACH (group teammate_pairs ALL) GENERATE 
	COUNT_STAR(teammate_pairs) AS total;

DUMP @;
