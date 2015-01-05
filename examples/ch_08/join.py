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
      symbol = 'A'
      countryName = splits[0]
      country2digit = splits[1]
      yield country2digit, [symbol, countryName]
    else: # person data
      symbol = 'B'
      personName = splits[0]
      personType = splits[1]
      country2digit = splits[2]
      yield country2digit, [symbol, personName, personType]
  
  def reducer(self, key, values):
    values = [x for x in values]
    if len(values) > 1: # our join hit
      country = values[0]
      for value in values[1:]:
        yield key, [country, value]
    else: # our join missed
      pass
      
if __name__ == '__main__':
  MRJoin.run()
