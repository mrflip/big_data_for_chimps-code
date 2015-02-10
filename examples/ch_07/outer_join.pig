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

hof_bat = LOAD '/data/gold/sports/baseball/hof_bat.tsv' AS (
    player_id:chararray, inducted_by:chararray,
    is_inducted:boolean, is_pending:int,
    max_pct:long, n_ballots:long, hof_score:long,
    year_eligible:long, year_inducted:long, pcts:chararray
);

career_stats = FOREACH (JOIN
    bat_careers BY player_id LEFT OUTER,
    hof_bat BY player_id) GENERATE
        bat_careers::player_id, 
        bat_careers::n_seasons,
        hof_bat::year_inducted AS hof_year;

DUMP @;
