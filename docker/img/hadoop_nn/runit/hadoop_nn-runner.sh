#!/bin/bash
exec 2>&1

echo "********************************"
echo 
echo "Namenode runit script invoked at `date`"
echo

daemon_user=hdfs

# keep runit from killing the system if this script crashes
sleep 1

# /etc/defaults overrides
. /etc/default/hadoop
. /etc/default/hadoop-hdfs-namenode

# System hadoop config
. /usr/lib/hadoop/libexec/hadoop-config.sh

# Conf dir overrides if any
if [ -f "$HADOOP_CONF_DIR/hadoop-env.sh" ] ; then
  . "$HADOOP_CONF_DIR/hadoop-env.sh"
fi

# Set the ulimit, then prove the new settings got there
ulimit -S -n 65535 
chpst -u $daemon_user /bin/bash -c 'ulimit -S -a'

# Dump the salient env vars now that there's no doubt
echo
echo "HADOOP_OPTS         '$HADOOP_OPTS'"
echo "HADOOP_CONF_DIR     '$HADOOP_CONF_DIR'"
echo "JAVA_HOME           '$JAVA_HOME'"
env | egrep '^(HADOOP|YARN|JAVA_HOME)'
echo

echo ; echo "Launching Namenode" ; echo

cd /var/lib/hadoop-hdfs
exec chpst -u $daemon_user /usr/bin/hdfs --config $HADOOP_CONF_DIR namenode < /dev/null

