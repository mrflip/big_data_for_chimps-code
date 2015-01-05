# Adapted for MrJob from Joe Stein's example at:
# http://allthingshadoop.com/2011/12/16/simple-hadoop-streaming-tutorial-using-joins-and-keys-with-python/

import sys, os, re
from mrjob.job import MRJob

class MRJoin(MRJob):
  
  # Performs secondary search
  SORT_VALUES = True
  
  def mapper(self, _, line):    
    splits = line.rstrip("\n").split("|")
    
    if len(splits) == 2: # country data
      symbol = 'A' # make country sort before person data
      country2digit = splits[1]
      yield country2digit, [symbol, splits]
    else: # person data
      symbol = 'B'
      country2digit = splits[2]
      yield country2digit, [symbol, splits]
  
  def reducer(self, key, values):
    countries = [] # should come first, as they are sorted on artificia key 'A'
    for value in values:
      if value[0] == 'A':
        countries.append(value)
      if value[0] == 'B':
        for country in countries:
          yield key, country[1:] + value[1:]
      
if __name__ == '__main__':
  MRJoin.run()
