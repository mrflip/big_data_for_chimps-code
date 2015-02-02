#!/bin/bash
set -x ; set -e ; date

DATAFU_HOME=/usr/local/datafu
DATAFU_VERSION=git

#
# Datafu
#

git clone git://git.apache.org/incubator-datafu.git $DATAFU_HOME-$DATAFU_VERSION
ln  -s $DATAFU_HOME-$DATAFU_VERSION $DATAFU_HOME

cd $DATAFU_HOME

./gradlew :datafu-pig:assemble

ln -s $DATAFU_HOME/datafu-pig/build/libs/datafu-pig-*-SNAPSHOT.jar $PIG_HOME/lib/datafu.jar

