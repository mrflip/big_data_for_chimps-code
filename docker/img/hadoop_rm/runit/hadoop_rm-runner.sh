#!/bin/bash
exec 2>&1

echo "********************************"
echo 
echo "Resourcemanager runit script invoked at `date`"
echo

# keep runit from killing the system if this script crashes
sleep 1

# System hadoop config
. /usr/lib/hadoop/libexec/hadoop-config.sh

# /etc/defaults overrides if any
if [ -f "/etc/default/hadoop-yarn-resourcemanager" ] ; then
  . "/etc/default/hadoop-yarn-resourcemanager"
fi

# Conf dir overrides if any
if [ -f "$HADOOP_CONF_DIR/hadoop-env.sh" ] ; then
  . "$HADOOP_CONF_DIR/hadoop-env.sh"
fi

# Set the ulimit, then prove the new settings got there
ulimit -S -n 65535 
chpst -u hdfs bash -c 'ulimit -S -a'

# echo "also: $HADOOP_LOGFILE -  - $HADOOP_ROOT_LOGGER - $HADOOP_SECURITY_LOGGER - $HDFS_AUDIT_LOGGER - $HADOOP_JHS_LOGGER - $HADOOP_MAPRED_HOME - $HADOOP_MAPRED_IDENT_STRING - $HADOOP_MAPRED_LOGFILE - $HADOOP_MAPRED_NICENESS - $HADOOP_MAPRED_ROOT_LOGGER - $HADOOP_NICENESS - $HADOOP_PID_DIR - $YARN_IDENT_STRING - $YARN_LOGFILE - $YARN_LOG_DIR - $YARN_NICENESS - $YARN_ROOT_LOGGER'"
# set | sort

# Dump the salient env vars now that there's no doubt
echo
echo "HADOOP_HDFS_HOME    '$HADOOP_HDFS_HOME'"
echo "HADOOP_OPTS         '$HADOOP_OPTS'"
echo "HADOOP_CONF_DIR     '$HADOOP_CONF_DIR'"
echo "CLASSPATH           '$CLASSPATH'"
echo "HADOOP_IDENT_STRING '$HADOOP_IDENT_STRING'"
echo "HADOOP_LOG_DIR      '$HADOOP_LOG_DIR'"
echo "YARN_IDENT_STRING   '$YARN_IDENT_STRING'"
echo "YARN_LOG_DIR        '$YARN_LOG_DIR'"
echo "JAVA_HOME           '$JAVA_HOME'"

echo ; echo "Launching Resourcemanager" ; echo

cd /var/lib/hadoop-hdfs
exec chpst -u yarn /usr/bin/yarn --config $HADOOP_CONF_DIR resourcemanager < /dev/null

