#!/bin/bash
set -e ; set -x

ls -l $HADOOP_BULK_DIR
mkdir -p            $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history
chown mapred:hadoop $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history
chmod 775           $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history
ls -l $HADOOP_BULK_DIR
