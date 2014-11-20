#!/bin/bash
set -e ; set -v

#
# Pig
#

$safe_apt_install ant maven2

git clone https://github.com/apache/pig.git $PIG_HOME-$PIG_VERSION
ln  -s $PIG_HOME-$PIG_VERSION $PIG_HOME

cd $PIG_HOME
git checkout --track -b branch-$PIG_VERSION origin/branch-$PIG_VERSION

perl -pi -e 's/hadoop-(.*)=2.0.3-alpha/hadoop-\1=2.5.0/g' ivy/libraries.properties

ant -Dhadoopversion=23 jar jar-withouthadoop

mvn org.apache.maven.plugins:maven-install-plugin:2.5:install-file \
    -Dfile=build/pig-0.13.1-SNAPSHOT.jar \
    -DgroupId=org.apache.pig \
    -DartifactId=pig \
    -Dversion=0.13.1-h2 \
    -Dpackaging=jar

