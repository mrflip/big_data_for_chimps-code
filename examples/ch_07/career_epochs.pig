bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

mod_seasons = FILTER bat_seasons BY ((year_id >= 1900) AND (lg_id == 'NL' OR lg_id == 'AL'));

age_seasons = FOREACH mod_seasons {
    young = (age <= 21               ? true : false);
    prime = (age >= 22 AND age <= 29 ? true : false);
    older = (age >= 30               ? true : false);
    OB = H + BB + HBP;
    TB = h1B + 2*h2B + 3*h3B + 4*HR;
    GENERATE
        player_id, 
        year_id,
        PA AS PA_all, 
		AB AS AB_all, 
		OB AS OB_all, 
		TB AS TB_all,
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
        PA_all   AS PA_all,
        PA_young AS PA_young,
        PA_prime AS PA_prime,
        PA_older AS PA_older,
        --
        MIN(age_seasons.year_id)  AS beg_year,
        MAX(age_seasons.year_id)  AS end_year,
        --
        OBP_all   + SLG_all       AS OPS_all:float,
        (PA_young >= 700 ? OBP_young + SLG_young : Null) AS OPS_young:float,
        (PA_prime >= 700 ? OBP_prime + SLG_prime : Null) AS OPS_prime:float,
        (PA_older >= 700 ? OBP_older + SLG_older : Null) AS OPS_older:float,
        --
        COUNT_STAR(age_seasons)   AS n_seasons,
        SUM(age_seasons.is_young) AS n_young,
        SUM(age_seasons.is_prime) AS n_prime,
        SUM(age_seasons.is_older) AS n_older
    ;
};

STORE career_epochs INTO 'career_epochs';
