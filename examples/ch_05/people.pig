-- Summary of Weight Field
REGISTER /usr/lib/pig/datafu.jar 

DEFINE VAR datafu.pig.stats.VAR();
DEFINE ApproxEdgeile datafu.pig.stats.StreamingQuantile( '0.01','0.05', '0.50', '0.95', '0.99');

people = LOAD '/data/gold/sports/baseball/people.tsv' USING PigStorage('\t') AS (
    player_id:chararray,
    birth_year:int,        birth_month:int,       birth_day: int,
    birth_city:chararray,  birth_state:chararray, birth_country: chararray,
    death_year:int,        death_month:int,       death_day: int,
    death_city:chararray,  death_state:chararray, death_country: chararray,
    name_first:chararray,  name_last:chararray,   name_given:chararray,
    height_in:int,         weight_lb:int,
    bats:chararray,        throws:chararray,
    beg_date:chararray,    end_date:chararray,    college:chararray,
    retro_id:chararray,    bbref_id:chararray
);

weight_summary = FOREACH (GROUP people ALL) {
    dist         = DISTINCT people.weight_lb;
    sorted_a     = FILTER   people.weight_lb BY weight_lb IS NOT NULL;
    sorted       = ORDER    sorted_a BY weight_lb;
    some         = LIMIT    dist.weight_lb 5;
    n_recs       = COUNT_STAR(people);
    n_notnulls   = COUNT(people.weight_lb);
    GENERATE
        group,
        AVG(people.weight_lb)             AS avg_val,
        SQRT(VAR(people.weight_lb))       AS stddev_val,
        MIN(people.weight_lb)             AS min_val,
        FLATTEN(ApproxEdgeile(sorted))  AS (p01, p05, p50, p95, p99),
        MAX(people.weight_lb)           AS max_val,
        n_recs                          AS n_recs,
        n_recs - n_notnulls             AS n_nulls,
        COUNT_STAR(dist)                AS cardinality,
        SUM(people.weight_lb)           AS sum_val,
        BagToString(some, '^')          AS some_vals
    ;
};

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

height_hist	  = binned_histogram(people, 'height_in', 40, 80);
weight_hist	  = binned_histogram(people, 'weight_lb', 10, 300);

birthmo_hist = histogram(people, 'birth_month');
deathmo_hist = histogram(people, 'death_month');
