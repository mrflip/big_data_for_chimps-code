#!/usr/bin/python
"""Example MapReduce job: pig latinize words.
"""
import sys, re

def truncate_to_hour(sighted_at):
  return sighted_at[0:13]


def mapper(line):
  fields = line.rstrip("\n").split("\t", 8)
  sighted_at, reported_at, location, blank, duration, description, latitude, longitude, rest = fields
  
  hour_sighted = (truncate_to_hour(sighted_at), "1")
  return "\t".join(hour_sighted)

if __name__ == '__main__':
  for line in sys.stdin:
    print mapper(line)
