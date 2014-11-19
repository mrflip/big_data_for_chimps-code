#!/bin/bash
set -e ; set -v

$safe_apt_install ant maven2

#
# Pig
#

git clone https://github.com/apache/pig.git $PIG_HOME-$PIG_VERSION
ln  -s $PIG_HOME-$PIG_VERSION $PIG_HOME

cd $PIG_HOME
git checkout --track -b branch-$PIG_VERSION origin/branch-$PIG_VERSION

ant -Dhadoopversion=23 jar
