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


-- Vital Stats Part 1
HR_stats = FOREACH (GROUP bat_careers BY ALL) GENERATE COUNT_STAR(bat_careers) AS n_players;

HR_stats = FOREACH (GROUP bat_careers BY ALL) GENERATE COUNT_STAR(bat_careers) AS ct;
HR_hist  = FOREACH (GROUP bat_careers BY HR) {
    ct = COUNT_STAR(bats);
    GENERATE HR as val,
        ct/( (long)HR_stats.ct ) AS freq,
        ct;
};
STORE HR_stats INTO 'HR_stats';


-- Re-injecting Global Values
SET HR_stats_n_total=`cat HR_stats`;

HR_hist  = FOREACH (GROUP bat_careers BY HR) {
    ct = COUNT_STAR(bat_careers);
    GENERATE 
        HR as val, 
        ct AS ct,
        ct/( (double)HR_stats_n_total) AS freq,
        ct;
};


-- Calculating a Histogram within a Group
sig_seasons = FILTER bat_seasons BY ((year_id >= 1900) AND (lg_id == 'NL' OR lg_id == 'AL') AND (PA >= 450));

REGISTER /usr/lib/pig/datafu.jar 
DEFINE CountVals datafu.pig.bags.CountEach('flatten');
DEFINE SPRINTF datafu.pig.util.SPRINTF();

-- Used a lot below
binned = FOREACH sig_seasons GENERATE
    ( 5 * ROUND(year_id/ 5.0f)) AS year_bin,
    (20 * ROUND(H      /20.0f)) AS H_bin;

hist_by_year_bags = FOREACH (GROUP binned BY year_bin) {
    H_hist_cts = CountVals(binned.H_bin);
    GENERATE 
        group AS year_bin, 
        H_hist_cts AS H_hist_cts;
};

-- Won't work
hist_by_year_bags = FOREACH (GROUP binned BY year_bin) {
	H_hist_cts = CountVals(binned.H_bin);
	tot        = 1.0f*COUNT_STAR(binned);
	H_hist_rel = FOREACH H_hist_cts GENERATE 
		H_bin, 
		(float)count/tot;
	GENERATE 
	    group AS year_bin, 
	    H_hist_cts AS H_hist_cts, 
	    tot AS tot;
};

-- Works
hist_by_year_bags = FOREACH (GROUP binned BY year_bin) {
    H_hist_cts = CountVals(binned.H_bin);
    tot        = COUNT_STAR(binned);
    GENERATE
        group      AS year_bin,
        H_hist_cts AS H_hist,
        {(tot)}    AS info:bag{(tot:long)}; -- single-tuple bag we can feed to CROSS
};

hist_by_year = FOREACH hist_by_year_bags {
    -- Combines H_hist bag {(100,93),(120,198)...} and dummy tot bag {(882.0)}
    -- to make new (bin,count,total) bag: {(100,93,882.0),(120,198,882.0)...}
    H_hist_with_tot = CROSS H_hist, info;
    -- Then turn the (bin,count,total) bag into the (bin,count,freq) bag we want
    H_hist_rel = FOREACH H_hist_with_tot GENERATE 
        H_bin, 
        count AS ct, 
        count/((float)tot) AS freq;
        
    GENERATE 
        year_bin, 
        H_hist_rel;
};


-- Dumping Readable Results
year_hists_bags = FOREACH (GROUP binned BY year_bin) {
    H_cts = CountVals(binned.H_bin);
    tot   = COUNT_STAR(binned);
    GENERATE
        group   AS year_bin,
        H_cts  AS H_cts:bag{t:(bin:int, ct:int)},
        {(tot)} AS info:bag{(tot:long)}; -- single-tuple bag we can feed to CROSS
};

year_hists = FOREACH year_hists_bags {
    -- Combines HH_hist bag {(100,93),(120,198)...} and dummy tot bag {(882.0)}
    -- to make new (bin,count,total) bag: {(100,93,882.0),(120,198,882.0)...}
    H_hist_with_tot = CROSS H_cts, info;
    -- Then turn the (bin,count,total) bag into the (bin,count,freq) bag we want
    H_hist_rel = FOREACH H_hist_with_tot
    GENERATE 
        bin, 
        ct, 
        ct/((float)tot) AS freq;
    GENERATE 
        year_bin, 
        H_hist_rel;
};

year_hists_H = FOREACH year_hists {
    H_hist_rel_o = ORDER H_hist_rel BY bin ASC;
    H_hist_rel_x = FILTER H_hist_rel_o BY (bin >= 90);
    H_hist_vis   = FOREACH H_hist_rel_x GENERATE
        SPRINTF('%1$3d: %3$4.0f', bin, ct, (double)ROUND(100*freq));
        
    GENERATE 
        year_bin, 
        BagToString(H_hist_vis, '  ');
};


-- Create Indicator Fields on Each Figure of Merit for the Season
mod_seasons = FILTER bat_seasons BY ((year_id >= 1900) AND (lg_id == 'NL' OR lg_id == 'AL'));

standards = FOREACH mod_seasons {
    OBP    = 1.0*(H + BB + HBP) / PA;
    SLG    = 1.0*(h1B + 2*h2B + 3*h3B + 4*HR) / AB;
    
    GENERATE
        player_id,
        (H   >=   180 ? 1 : 0) AS hi_H,
        (HR  >=    30 ? 1 : 0) AS hi_HR,
        (RBI >=   100 ? 1 : 0) AS hi_RBI,
        (OBP >= 0.400 ? 1 : 0) AS hi_OBP,
        (SLG >= 0.500 ? 1 : 0) AS hi_SLG
    ;
};

career_standards = FOREACH (GROUP standards BY player_id) GENERATE
    group AS player_id,
    COUNT_STAR(standards) AS n_seasons,
    SUM(standards.hi_H)   AS hi_H,
    SUM(standards.hi_HR)  AS hi_HR,
    SUM(standards.hi_RBI) AS hi_RBI,
    SUM(standards.hi_OBP) AS hi_OBP,
    SUM(standards.hi_SLG) AS hi_SLG
;


-- Summarizing Multiple Subsets of a Group Simultaneously
age_seasons = FOREACH mod_seasons {
    young = (age <= 21               ? true : false);
    prime = (age >= 22 AND age <= 29 ? true : false);
    older = (age >= 30               ? true : false);
    OB = H + BB + HBP;
    TB = h1B + 2*h2B + 3*h3B + 4*HR;
    GENERATE
        player_id, year_id,
        PA AS PA_all, AB AS AB_all, OB AS OB_all, TB AS TB_all,
        (young ? 1 : 0) AS is_young,
        (young ? PA : 0) AS PA_young, (young ? AB : 0) AS AB_young,
        (young ? OB : 0) AS OB_young, (young ? TB : 0) AS TB_young,
        (prime ? 1 : 0) AS is_prime,
        (prime ? PA : 0) AS PA_prime, (prime ? AB : 0) AS AB_prime,
        (prime ? OB : 0) AS OB_prime, (prime ? TB : 0) AS TB_prime,
        (older ? 1 : 0) AS is_older,
        (older ? PA : 0) AS PA_older, (older ? AB : 0) AS AB_older,
        (older ? OB : 0) AS OB_older, (older ? TB : 0) AS TB_older
    ;
};

-- Career Epochs
career_epochs = FOREACH (GROUP age_seasons BY player_id) {
    PA_all    = SUM(age_seasons.PA_all  );
    PA_young  = SUM(age_seasons.PA_young);
    PA_prime  = SUM(age_seasons.PA_prime);
    PA_older  = SUM(age_seasons.PA_older);
    -- OBP = (H + BB + HBP) / PA
    OBP_all   = 1.0f*SUM(age_seasons.OB_all)   / PA_all  ;
    OBP_young = 1.0f*SUM(age_seasons.OB_young) / PA_young;
    OBP_prime = 1.0f*SUM(age_seasons.OB_prime) / PA_prime;
    OBP_older = 1.0f*SUM(age_seasons.OB_older) / PA_older;
    -- SLG = TB / AB
    SLG_all   = 1.0f*SUM(age_seasons.TB_all)   / SUM(age_seasons.AB_all);
    SLG_prime = 1.0f*SUM(age_seasons.TB_prime) / SUM(age_seasons.AB_prime);
    SLG_older = 1.0f*SUM(age_seasons.TB_older) / SUM(age_seasons.AB_older);
    SLG_young = 1.0f*SUM(age_seasons.TB_young) / SUM(age_seasons.AB_young);
    --
    GENERATE
        group AS player_id,
        MIN(age_seasons.year_id)  AS beg_year,
        MAX(age_seasons.year_id)  AS end_year,
        --
        OBP_all   + SLG_all       AS OPS_all:float,
        (PA_young >= 700 ? OBP_young + SLG_young : null) AS OPS_young:float,
        (PA_prime >= 700 ? OBP_prime + SLG_prime : null) AS OPS_prime:float,
        (PA_older >= 700 ? OBP_older + SLG_older : null) AS OPS_older:float,
        --
        COUNT_STAR(age_seasons)   AS n_seasons,
        SUM(age_seasons.is_young) AS n_young,
        SUM(age_seasons.is_prime) AS n_prime,
        SUM(age_seasons.is_older) AS n_older
    ;
};


-- Players Who Never Played for the Redsox
player_soxness = FOREACH bat_seasons GENERATE
    player_id, 
    (team_id == 'BOS' ? 1 : 0) AS is_soxy;

player_soxness_g = FILTER
    (GROUP player_soxness BY player_id)
    BY MAX(player_soxness.is_soxy) == 0;

never_sox = FOREACH player_soxness_g GENERATE 
    group AS player_id;

