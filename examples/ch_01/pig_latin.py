"""Example MapReduce job: pig latinize words.
"""
from mrjob.job import MRJob
import re

WORD_RE = re.compile(r"\b([bcdfghjklmnpqrstvwxz]*)([\w\']+)")

class MRWordFreqCount(MRJob):

    def mapper(self, _, line):
        parts = WORD_RE.findall(line)
        for part in parts:
          init, rest = part
          init = 'w' if not init else init
          yield (''.join(part), rest + init + 'ay')

if __name__ == '__main__':
     MRWordFreqCount.run()
