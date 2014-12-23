bat_careers = LOAD 'bat_careers' AS (
    player_id: chararray,
    n_seasons: long,
    card_teams: long,
    beg_year: int,
    end_year: int,
    G: long,
    PA: long,
    AB: long,
    HBP: long,
    SH: long,
    BB: long,
    H: long,
    h1B: long,
    h2B: long,
    h3B: long,
    HR: long,
    R: long,
    RBI: long,
    OBP: double,
    SLG: double,
    OPS: double
);

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Histogram of Number of Seasons
vals = FOREACH bat_careers GENERATE n_seasons AS bin;
seasons_hist = FOREACH (GROUP vals BY bin) GENERATE
    group AS bin, COUNT_STAR(vals) AS ct;

vals = FOREACH (GROUP bat_seasons BY (player_id, name_first, name_last)) GENERATE
    COUNT_STAR(bat_seasons) AS bin, flatten(group);
seasons_hist = FOREACH (GROUP vals BY bin) {
    some_vals = LIMIT vals 3;
    GENERATE group AS bin, COUNT_STAR(vals) AS ct, BagToString(some_vals, '|');
};


-- Meaningless
G_vals = FOREACH bat_seasons GENERATE G AS val;
G_hist = FOREACH (GROUP G_vals BY val) GENERATE
	group AS val, 
	COUNT_STAR(G_vals) AS ct;

-- Binning makes it sensible
G_vals = FOREACH bat_seasons GENERATE 50*FLOOR(G/50) AS val;
G_hist = FOREACH (GROUP G_vals BY val) GENERATE
    group AS val, 
    COUNT_STAR(G_vals) AS ct;


-- Macros for histograms
DEFINE histogram(table, key) RETURNS dist {
    vals = FOREACH $table GENERATE $key;
    $dist = FOREACH (GROUP vals BY $key) GENERATE
        group AS val, 
        COUNT_STAR(vals) AS ct;
};

DEFINE binned_histogram(table, key, binsize, maxval) RETURNS dist {
    -- A list of numbers from 0-9999
    numbers = LOAD '/data/gold/numbers10k.txt' AS (number:int);
    vals = FOREACH $table GENERATE (long)(FLOOR($key / $binsize) * $binsize) AS bin;
    all_bins = FOREACH numbers GENERATE (number * $binsize) AS bin;
    all_bins = FILTER  all_bins BY (bin <= $maxval);
    $dist = FOREACH (COGROUP vals BY bin, all_bins BY bin) GENERATE
        group AS bin, 
        (COUNT_STAR(vals) == 0L ? 0L : COUNT_STAR(vals)) AS ct;
};

career_G_hist	    = binned_histogram(bat_careers, 'G', 50, 3600);
career_G_hist_2   = binned_histogram(bat_careers, 'G', 2, 3600);
career_G_hist_200 = binned_histogram(bat_careers, 'G', 200, 3600);
