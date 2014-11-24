#!/usr/bin/python
# Example MapReduce job: count ufo sightings by hour. 
# Based on example at http://www.michael-noll.com/tutorials/writing-an-hadoop-mapreduce-program-in-python/

import sys, re

current_days = None
curreent_count = 0
days = None

# Loop tbrough each line from standard input
for line in sys.stdin:
  # split the line into two values, using the tab character
  days, count = line.rstrip("\n").split("\t", 1)
  
  # Streaming always reads strings, so must convert to integer
  try:
    count = int(count)
  except:
    sys.stderr.write("Can't convert '{}' to integer\n".format(count))
    continue
  
  # If sorted input key is the same, increment counter
  if current_days == days:
    current_count += count
  # If the key has changed...
  else:
    # This is a new reduce key, so emit the total of the last key
    if current_days: 
      print "{}\t{}".format(current_days, current_count)
    
    # And set the new key and count to the new reduce key/reset total
    current_count = count
    current_days = days

# Emit the last reduce key
if current_days == days:
  print "{}\t{}".format(current_days, current_count)
