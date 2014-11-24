#!/usr/bin/python
# Example MapReduce job: count ufo sightings by location.

import sys, re, time, iso8601

# Pull out city/state from ex: Town, ST
word_finder = re.compile("([\w\s]+),\s(\w+)")

# Loop through each line from standard input
for line in sys.stdin:
  # Remove the carriage return, and split on tabs - maximum of 3 fields
  fields = line.rstrip("\n").split("\t", 2)
  try:
    # Parse the two dates, then find the time between them
    sighted_at, reported_at, rest = fields
    sighted_dt = iso8601.parse_date(sighted_at)
    reported_dt = iso8601.parse_date(reported_at)
    diff = reported_dt - sighted_dt
  except:
    sys.stderr.write("Bad line: {}".format(line))
    continue
  # Emit the number of days and one
  print "\t".join((str(diff.days), "1"))
