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

-- Converting types
birthplaces = FOREACH people GENERATE
    player_id,
    StringConcat((chararray)birth_year, '-', (chararray)birth_month, '-', (chararray)birth_day) AS birth_date
;

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);
bat_seasons = FILTER bat_seasons BY PA > 0 AND AB > 0;

-- Managing types of floating point numbers
obp_1 = FOREACH bat_seasons {
  OBP = 1.0f * (H + BB + HBP) / PA; -- constant is a float
  GENERATE OBP;                     -- making OBP a float
};
-- obp_1: {OBP: float}

obp_2 = FOREACH bat_seasons {
  OBP = 1.0 * (H + BB + HBP) / PA;  -- constant is a double
  GENERATE OBP;                     -- making OBP a double
};
-- obp_2: {OBP: double}

obp_3 = FOREACH bat_seasons {
  OBP = (float)(H + BB + HBP) / PA; -- typecast forces floating-point arithmetic
  GENERATE OBP AS OBP;              -- making OBP a float
};
-- obp_3: {OBP: float}

obp_4 = FOREACH bat_seasons {
  OBP = 1.0 * (H + BB + HBP) / PA;  -- constant is a double
  GENERATE OBP AS OBP:float;        -- but OBP is explicitly a float
};
-- obp_4: {OBP: float}

broken = FOREACH bat_seasons {
  OBP = (H + BB + HBP) / PA;        -- all int operands means integer math and zero as result
  GENERATE OBP AS OBP:float;        -- even though OBP is explicitly a float
};

REGISTER /usr/lib/pig/datafu.jar
DEFINE SPRINTF datafu.pig.util.SPRINTF();

-- Rounding experiments
rounded = FOREACH bat_seasons GENERATE
    (ROUND(1000.0f*(H + BB + HBP) / PA)) / 1000.0f AS round_and_typecast,
    ((int)(1000.0f*(H + BB + HBP) / PA)) / 1000.0f AS typecast_only,
    (FLOOR(1000.0f*(H + BB + HBP) / PA)) / 1000    AS floor_and_typecast,
    SPRINTF('%5.3f', 1.0f*(H + BB + HBP) / PA)     AS but_if_you_want_a_string_just_say_so,
    1.0f*(H + BB + HBP) / PA                       AS full_value
;

