bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Numbers, from 0 to 9999
numbers = LOAD '/data/gold/numbers10k.txt' AS (number:int);

-- Get a count of hits per player, across all player seasons
player_hits = FOREACH (GROUP bat_seasons BY player_id) GENERATE
    100 * ROUND(SUM(bat_seasons.H)/100.0) AS bin;

-- Get the maximum player hits bin to filter the numbers relation
max_hits = FOREACH (GROUP player_hits ALL) GENERATE MAX(player_hits.bin) AS max_bin;

-- Count the number of occurrences for each bin
histogram = FOREACH (GROUP player_hits BY bin) GENERATE
    group AS bin, 
    COUNT_STAR(player_hits) AS total;

-- Calculate the complete set of histogram bins up to our limit
histogram_bins = FOREACH (FILTER numbers BY 100 * number <= max_hits.max_bin) GENERATE 100 * number AS bin;

-- Finally, join the histogram bins with the histogram data to get our gap-less histogram
filled_histogram = FOREACH (JOIN histogram_bins BY bin LEFT OUTER, histogram BY bin) GENERATE
    histogram_bins::bin,
    (total IS NULL ? 0 : total)
;

DUMP @;
