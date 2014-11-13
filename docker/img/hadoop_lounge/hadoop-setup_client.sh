#!/bin/bash
set -e ; set -v

# Directories
#
mkdir -p $HADOOP_LOG_DIR/pig-app
mkdir -p $HADOOP_LOG_DIR/hive-app
mkdir -p $HADOOP_LOG_DIR/hue-app

ln -snf $HADOOP_LOG_DIR/pig-app  /var/log/pig
ln -snf $HADOOP_LOG_DIR/hive-app /var/log/hive
ln -snf $HADOOP_LOG_DIR/hue-app  /var/log/hue

chown hive:hive $HADOOP_LOG_DIR/hive-app
chown hue:hue   $HADOOP_LOG_DIR/hue-app

# Hadoop client basics
#
$safe_apt_install hadoop-client hadoop-doc zookeeper-bin
# # hadoop-hdfs-nfs3

# Oozie, Pig, Hive, Mr. Job
#
$safe_apt_install pig pig-udf-datafu
$safe_apt_install hive
$safe_apt_install python-mrjob
$safe_apt_install oozie-client  
$safe_apt_install hive-hcatalog hive-webhcat hive-webhcat-server

# Hadoop Hue -- pretty front-end to hadoop
#
$safe_apt_install hue

# broken.
# # The standard BSD words file, which is nice to have
# /usr/share/debconf/fix_db.pl
# $safe_apt_install --force-yes wamerican-huge

# $safe_apt_install apt-file
