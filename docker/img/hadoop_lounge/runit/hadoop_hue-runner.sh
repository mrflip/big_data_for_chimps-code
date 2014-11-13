#!/bin/bash
exec 2>&1

echo "********************************"
echo 
echo "Hue runit script invoked at `date`"
echo

daemon_user=hue


# keep runit from killing the system if this script crashes
sleep 1

export LOGDIR=$HADOOP_LOG_DIR/hive-app

# Start the process using the wrapper
export PYTHON_EGG_CACHE='/tmp/.hue-python-eggs'
mkdir -p ${PYTHON_EGG_CACHE}
chown -R $DAEMONUSER $LOGDIR ${PYTHON_EGG_CACHE}

colordiff -wu /etc/hue/conf.{empty,cluster}/hue.ini

/usr/lib/hue/build/env/bin/supervisor --log-dir=$HADOOP_LOG_DIR/hive-app --user=hue --group=hue


# hadoop.hdfs_clusters.default.webhdfs_url	Current value: http://localhost:50070/webhdfs/v1
# Failed to access filesystem root
# Resource Manager	Failed to contact Resource Manager at http://localhost:8088/ws/v1: HTTPConnectionPool(host='localhost', port=8088): Max retries exceeded with url: /ws/v1/cluster/apps (Caused by : [Errno 111] Connection refused)
# desktop.secret_key	Current value: 
# Secret key should be configured as a random string.
# Hive Editor	Failed to access Hive warehouse: /user/hive/warehouse
# Impala Editor	No available Impalad to send queries to.
# Oozie Editor/Dashboard	The app won't work without a running Oozie server
# Pig Editor	The app won't work without a running Oozie server

-p $PIDFILE -d --log-dir=$LOGDIR

PATH=/usr/lib/hue/build/env/bin:$PATH $DAEMON -- $DAEMON_OPTS
errcode=$?
return $errcode


# /etc/defaults overrides
. /etc/default/hadoop
. /etc/default/hadoop-hdfs-datanode

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

echo ; echo "Launching Datanode" ; echo

cd /var/lib/hadoop-hdfs
exec chpst -u $daemon_user /usr/bin/hdfs --config $HADOOP_CONF_DIR datanode < /dev/null
