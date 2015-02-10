/* Wikipedia pagecounts data described at https://dumps.wikimedia.org/other/pagecounts-raw/
   The first column is the project name. The second column is the title of the page retrieved, 
   the third column is the number of requests, and the fourth column is the size of the content returned. */
   
-- LOAD the data, which is space-delimited
pageviews = LOAD '/data/rawd/wikipedia/page_counts/pagecounts-20141126-230000.gz' 
    USING PigStorage(' ') AS (
        project_name:chararray, 
        page_title:chararray, 
        requests:long, 
        bytes:long
);

-- Group the data by project name, and then get counts of total pageviews and bytes sent for each project
per_project_counts = FOREACH (GROUP pageviews BY project_name) GENERATE
    group AS project_name, 
    SUM(pageviews.requests) AS total_pageviews, 
    SUM(pageviews.bytes) AS total_bytes;

-- Order the output by the total pageviews, in descending order
sorted_per_project_counts = ORDER per_project_counts BY total_pageviews DESC;

-- Store the data in our home directory
STORE sorted_per_project_counts INTO 'sorted_per_project_counts.out';

/*
LOAD SOURCE FILE
GROUP BY PROJECT NAME
SUM THE PAGE VIEWS AND BYTES FOR EACH PROJECT
ORDER THE RESULTS BY PAGE VIEWS, HIGHEST VALUE FIRST
STORE INTO FILE
*/