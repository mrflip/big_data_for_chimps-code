sightings = LOAD '/data/gold/geo/ufo_sightings/ufo_sightings.tsv'  AS (
    sighted_at: chararray,   reported_at: chararray,    location_str: chararray,
	shape: chararray,        duration_str: chararray,   description: chararray,
	lng: float,              lat: float,                city: chararray,
	county: chararray,       state: chararray,          country: chararray );

-- Take the 6th and 7th character from the original string, as in '2010-06-25T05:00:00Z', take '06'
month_count = FOREACH sightings GENERATE SUBSTRING(sighted_at, 5, 7) AS month;

-- Group by year_month, and then count the size of the 'bag' this creates to get a total
ufos_by_month    = FOREACH (GROUP month_count BY month) GENERATE
  group AS month, COUNT_STAR(month_count) AS total;
STORE ufos_by_month INTO './ufos_by_month.out';