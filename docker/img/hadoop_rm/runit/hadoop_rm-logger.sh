#!/bin/sh

log_dir=$HADOOP_LOG_DIR/resourcemanager-daemon

mkdir -p $log_dir

exec svlogd -tt $log_dir
