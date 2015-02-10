pageviews = LOAD '/data/rawd/wikipedia/page_counts/pagecounts-20141126-230000.gz' USING PigStorage(' ') AS (
   project_name:chararray, 
   page_title:chararray, 
   requests:long, 
   bytes:long
);

SET eps 0.001;

view_vals = FOREACH pageviews GENERATE
    (long)EXP( FLOOR(LOG((requests == 0 ? 0.001 : requests)) * 10)/10.0 ) AS bin;

hist_wp_view = FOREACH (GROUP view_vals BY bin) GENERATE
    group AS bin, 
    COUNT_STAR(view_vals) AS ct;
