-- Register the jar containing the UDFs
REGISTER /usr/lib/pig/datafu.jar
-- Murmur3, 32 bit version: a fast statistically smooth hash digest function
DEFINE Digest   datafu.pig.hash.Hasher('murmur3-32');

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);
bat_seasons = FILTER bat_seasons BY PA > 0 AND AB > 0;

-- Prepend a hash of the player_id
keyed_seasons = FOREACH bat_seasons GENERATE Digest(player_id) AS keep_hash, *;

some_seasons  = FOREACH (
    FILTER keyed_seasons BY (SUBSTRING(keep_hash, 0, 1) == '0')
  ) GENERATE $0..;
