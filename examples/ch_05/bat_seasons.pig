bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Load a summary of batting per player per season
bat_careers = FOREACH (GROUP bat_seasons BY player_id) {
    totG   = SUM(bat_seasons.G);
    totPA  = SUM(bat_seasons.PA);  totAB  = SUM(bat_seasons.AB);
    totHBP = SUM(bat_seasons.HBP); totSH  = SUM(bat_seasons.SH);
    totBB  = SUM(bat_seasons.BB);  totH   = SUM(bat_seasons.H);
    toth1B = SUM(bat_seasons.h1B); toth2B = SUM(bat_seasons.h2B);
    toth3B = SUM(bat_seasons.h3B); totHR  = SUM(bat_seasons.HR);
    totR   = SUM(bat_seasons.R);   totRBI = SUM(bat_seasons.RBI);
    OBP    = 1.0*(totH + totBB + totHBP) / totPA;
    SLG    = 1.0*(toth1B + 2*toth2B + 3*toth3B + 4*totHR) / totAB;
    team_ids = DISTINCT bat_seasons.team_id;
    GENERATE
        group                          AS player_id,
        COUNT_STAR(bat_seasons)        AS n_seasons,
        COUNT_STAR(team_ids)           AS card_teams,
        MIN(bat_seasons.year_id)	   AS beg_year,
        MAX(bat_seasons.year_id)       AS end_year,
        totG   AS G,
        totPA  AS PA,  totAB  AS AB,  totHBP AS HBP,    --  $6 -  $8
        totSH  AS SH,  totBB  AS BB,  totH   AS H,      --  $9 - $11
        toth1B AS h1B, toth2B AS h2B, toth3B AS h3B,    -- $12 - $14
        totHR AS HR,   totR   AS R,   totRBI AS RBI,    -- $15 - $17
        OBP AS OBP, SLG AS SLG, (OBP + SLG) AS OPS      -- $18 - $20
    ;
};

STORE bat_careers INTO 'bat_careers';


-- Completely Summarizing a Field
weight_yr_stats = FOREACH (GROUP bat_seasons BY year_id) {
    dist         = DISTINCT bat_seasons.weight;
    sorted_a     = FILTER   bat_seasons.weight BY weight IS NOT NULL;
    sorted       = ORDER    sorted_a BY weight;
    some         = LIMIT    dist.weight 5;
    n_recs       = COUNT_STAR(bat_seasons);
    n_notnulls   = COUNT(bat_seasons.weight);
    GENERATE
        group,
        AVG(bat_seasons.weight)        AS avg_val,
        SQRT(VAR(bat_seasons.weight))  AS stddev_val,
        MIN(bat_seasons.weight)        AS min_val,
        FLATTEN(ApproxEdgeile(sorted)) AS (p01, p05, p50, p95, p99),
        MAX(bat_seasons.weight)        AS max_val,
        --
        n_recs                         AS n_recs,
        n_recs - n_notnulls            AS n_nulls,
        COUNT_STAR(dist)               AS cardinality,
        SUM(bat_seasons.weight)        AS sum_val,
        BagToString(some, '^')         AS some_vals
    ;
};
