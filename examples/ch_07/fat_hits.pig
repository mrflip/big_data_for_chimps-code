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

fatness = FOREACH people GENERATE
    player_id, name_first, name_last,
    height_in, weight_lb;

slugging_stats = FOREACH (FILTER bat_careers BY (PA > 1000))
    GENERATE 
        player_id, 
        SLG;

slugging_fatness_join = JOIN
    fatness        BY player_id,
    slugging_stats BY player_id;

just_20 = LIMIT slugging_fatness_join 20; DUMP @;

DESCRIBE just_20

/*
{
    fatness::player_id: chararray,
    fatness::name_first: chararray,
    fatness::name_last: chararray,
    fatness::height_in: int,
    fatness::weight_lb: int,
    slugging_stats::player_id: chararray,
    slugging_stats::SLG: double
}
*/

bmis = FOREACH (JOIN fatness BY player_id, slugging_stats BY player_id) {
    
    BMI = 703.0*weight_lb/(double)(height_in*height_in);

    GENERATE 
        fatness::player_id, 
        name_first, 
        name_last,
        SLG, 
        height_in, 
        weight_lb, 
        BMI;
};
