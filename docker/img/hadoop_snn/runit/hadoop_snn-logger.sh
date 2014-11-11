#!/bin/sh

log_dir=$HADOOP_LOG_DIR/secondarynamenode-daemon

mkdir -p $log_dir

exec svlogd -tt $log_dir
