#!/bin/bash
set -e ; set -v

# Directories
#
mkdir -p $HADOOP_LOG_DIR/pig-app
mkdir -p $HADOOP_LOG_DIR/hive-app

ln -snf $HADOOP_LOG_DIR/pig-app  /var/log/pig
ln -snf $HADOOP_LOG_DIR/hive-app /var/log/hive

chown hive:hive $HADOOP_LOG_DIR/hive-app

# Hadoop client basics
#
$safe_apt_install hadoop-client hadoop-doc zookeeper-bin
# # hadoop-hdfs-nfs3

# Hive, Oozie, Mr. Job
#
$safe_apt_install hive
$safe_apt_install python-mrjob
$safe_apt_install oozie-client  
$safe_apt_install hive-hcatalog hive-webhcat hive-webhcat-server

