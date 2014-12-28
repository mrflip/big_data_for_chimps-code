career_epochs = LOAD 'career_epochs' AS (
    player_id: chararray,
    PA_all: long,
    PA_young: long,
    PA_prime: long,
    PA_older: long,
    beg_year: int,
    end_year: int,
    OPS_all: float,
    OPS_young: float,
    OPS_prime: float,
    OPS_older: float,
    n_seasons: long,
    n_young: long,
    n_prime: long,
    n_older: long
);

career_epochs = FILTER career_epochs BY
    ((PA_all >= 2000) AND (n_seasons >= 5) AND (OPS_all >= 0.650));

career_young = ORDER career_epochs BY OPS_young DESC; top_10_young = LIMIT career_young 10;
career_prime = ORDER career_epochs BY OPS_prime DESC; top_10_prime = LIMIT career_prime 10;
career_older = ORDER career_epochs BY OPS_older DESC; top_10_older = LIMIT career_older 10;

DUMP top_10_young;
DUMP top_10_prime;
DUMP top_10_older;


-- Ordering by multiple columns
career_older = ORDER career_epochs
	BY n_older DESC, n_prime DESC;

-- Makes sure that ties are always broken the same way.
career_older = ORDER career_epochs
    BY n_older DESC, n_prime DESC, player_id ASC;


-- fails!
by_diff_older = ORDER career_epochs BY (OPS_older - OPS_prime) DESC;

by_diff_older = FOREACH career_epochs GENERATE 
    OPS_older - OPS_prime AS diff, 
    player_id..;
by_diff_older = FOREACH (ORDER by_diff_older BY diff DESC, player_id) GENERATE 
    player_id..;


