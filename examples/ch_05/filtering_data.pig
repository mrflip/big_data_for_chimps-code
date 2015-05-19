DEFINE LENGTH org.apache.pig.piggybank.evaluation.string.LENGTH();

-- Load the events that make up baseball games
bats = LOAD '/data/gold/sports/baseball/events_lite.tsv.bz2' AS (
    game_id:chararray, event_seq:int, year_id:int, game_date:chararray,
    game_seq:int, away_team_id:chararray, home_team_id:chararray, inn:int,
    inn_home:int, beg_outs_ct:int, away_score:int, home_score:int,
    event_desc:chararray, event_cd:int, hit_cd:int, ev_outs_ct:int,
    ev_runs_ct:int, bat_dest:int, run1_dest:int, run2_dest:int, run3_dest:int,
    is_end_bat:int, is_end_inn:int, is_end_game:int, bat_team_id:chararray,
    fld_team_id:chararray, pit_id:chararray, bat_id:chararray,
    run1_id:chararray, run2_id:chararray, run3_id:chararray
);

-- Modern era
modern_bats = FILTER bats BY (year_id >= 1900);

-- Load a summary of batting per player per season
bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Modern era, American or National Leagues
modsig_stats = FILTER bat_seasons BY
    (PA >= 450) AND (year_id >= 1900) AND ((lg_id == 'AL') OR (lg_id == 'NL'));

-- Load the people that have played the game
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

people = FOREACH people GENERATE StringConcat(birth_city, ',', birth_state, ',', birth_country) AS birth_place, *;

-- People with known birth year/place
borned = FILTER people BY (LENGTH(birth_place) > 2) AND (birth_place IS NOT NULL);

-- Look for players with our co-author's names
namesakes = FILTER people BY (name_first MATCHES '(?i).*(russ|russell|flip|phil+ip).*');

-- Look for players who's names start with a lowercase or non-word, non-space character
funnychars = FILTER people BY (name_first MATCHES '^([^A-Z]|.*[^\\w\\s]).*');

-- Load data about ball parks and the teams that occupied them
park_team_years = LOAD '/data/gold/sports/baseball/park_team_years.tsv' USING PigStorage('\t') AS (
    park_id:chararray, team_id:chararray, year_id:long, beg_date:chararray, end_date:chararray, n_games:long
);

-- Filter to just American League eastern division teams
al_east_parks = FILTER park_team_years BY
  team_id IN ('BAL', 'BOS', 'CLE', 'DET', 'ML4', 'NYA', 'TBA', 'TOR', 'WS2');

