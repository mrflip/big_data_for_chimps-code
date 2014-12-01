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

-- Using a FOREACH to create a readable field value
birthplaces = FOREACH people GENERATE
    player_id,
    StringConcat(birth_city, ', ', birth_state, ', ', birth_country) AS birth_loc
    ;

bat_seasons = LOAD '/data/gold/sports/baseball/bat_seasons.tsv' USING PigStorage('\t') AS (
    player_id:chararray, name_first:chararray, name_last:chararray,     --  $0- $2
    year_id:int,        team_id:chararray,     lg_id:chararray,         --  $3- $5
    age:int,  G:int,    PA:int,   AB:int,  HBP:int,  SH:int,   BB:int,  --  $6-$12
    H:int,    h1B:int,  h2B:int,  h3B:int, HR:int,   R:int,    RBI:int  -- $13-$19
);

-- Using a nested FOREACH to cleanly compute metrics
bat_seasons = FILTER bat_seasons BY PA > 0 AND AB > 0;
core_stats  = FOREACH bat_seasons {
    TB   = h1B + 2*h2B + 3*h3B + 4*HR;
    OBP  = 1.0f*(H + BB + HBP) / PA;
    SLG  = 1.0f*TB / AB;
    OPS  = SLG + OBP;
    GENERATE
        player_id, name_first, name_last,   --  $0- $2
        year_id,   team_id,   lg_id,        --  $3- $5
        age,  G,   PA,  AB,   HBP, SH,  BB, --  $6-$12
        H,    h1B, h2B, h3B,  HR,  R,  RBI, -- $13-$19
        SLG, OBP, OPS;                      -- $20-$22
};

-- Formatting strings using a template (Only for Pig >= 0.14.0)
formatted = FOREACH bat_seasons GENERATE
    SPRINTF('%4d\t%-9s %-19s\tOBP %5.3f / %-3s %-3s\t%4$012.3e',
        year_id,  player_id,
        CONCAT(name_first, ' ', name_last),
        1.0f*(H + BB + HBP) / PA,
        (year_id >= 1900 ? '.'   : 'pre'),
        (PA >= 450       ? 'sig' : '.')
    ) AS OBP_summary:chararray;

REGISTER /usr/lib/pig/datafu.jar
DEFINE Coalesce datafu.pig.util.Coalesce();
DEFINE SPRINTF datafu.pig.util.SPRINTF();

-- Assembling complex types (Only for Pig >= 0.14.0)
people = FILTER people BY (beg_date IS NOT NULL) AND (end_date IS NOT NULL) AND (birth_year IS NOT NULL) AND (death_year IS NOT NULL);

date_converted = FOREACH people {
    beg_dt   = ToDate(CONCAT(beg_date, 'T00:00:00.000Z'));
    end_dt   = ToDate(end_date, 'yyyy-MM-dd', '+0000');
    birth_dt = ToDate(SPRINTF('%s-%s-%sT00:00:00Z', birth_year, Coalesce(birth_month,1), Coalesce(birth_day,1)));
    death_dt = ToDate(SPRINTF('%s-%s-%sT00:00:00Z', death_year, Coalesce(death_month,1), Coalesce(death_day,1)));

    GENERATE player_id, birth_dt, death_dt, beg_dt, end_dt, name_first, name_last;
};

-- Assemble a complex structure, could be used for example as a JSON record to return via an API
graphable = FOREACH people {
    birth_month = Coalesce(birth_month, 1); birth_day = Coalesce(birth_day, 1);
    death_month = Coalesce(death_month, 1); death_day = Coalesce(death_day, 1);
    beg_dt   = ToDate(beg_date);
    end_dt   = ToDate('yyyy-MM-dd', end_date);
    birth_dt = ToDate(SPRINTF('%s-%s-%s', birth_year, birth_month, birth_day));
    death_dt = ToDate(SPRINTF('%s-%s-%s', death_year, death_month, death_day));
    --
    occasions = {
        ('birth', birth_year, birth_month, birth_day),
        ('death', death_year, death_month, death_day),
        ('debut', (int)SUBSTRING(beg_date,0,4), (int)SUBSTRING(beg_date,5,7), (int)SUBSTRING(beg_date,8,10)),
        ('lastg', (int)SUBSTRING(end_date,0,4), (int)SUBSTRING(end_date,5,7), (int)SUBSTRING(end_date,8,10))
    };
    --
    places = (
        (birth_dt, birth_city, birth_state, birth_country),
        (death_dt, death_city, death_state, death_country)
    );

    GENERATE
    player_id,
    occasions AS occasions:bag{occasion:(name:chararray, year:int, month:int, day:int)},
    places    AS places:tuple( birth:tuple(date, city, state, country),
                               death:tuple(date, city, state, country) )
    ;
};

-- Converting types
birthplaces = FOREACH people GENERATE
    player_id,
    StringConcat((chararray)birth_year, '-', (chararray)birth_month, '-', (chararray)birth_day) AS birth_date
;
  