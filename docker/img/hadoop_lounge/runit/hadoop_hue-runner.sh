#!/bin/bash
exec 2>&1

echo "********************************"
echo 
echo "Hue runit script invoked at `date`"
echo

daemon_user=hue

# keep runit from killing the system if this script crashes
sleep 1

export LOGDIR=$HADOOP_LOG_DIR/hue-app

# Start the process using the wrapper
export PYTHON_EGG_CACHE='/tmp/.hue-python-eggs'
mkdir -p ${PYTHON_EGG_CACHE}
chown -R $DAEMONUSER $LOGDIR ${PYTHON_EGG_CACHE}

colordiff -wu /etc/hue/conf.{empty,cluster}/hue.ini

# Set the ulimit, then prove the new settings got there
ulimit -S -n 65535 
chpst -u $daemon_user /bin/bash -c 'ulimit -S -a'

echo ; echo "Launching Hue" ; echo

cd /usr/lib/hue/
exec /usr/lib/hue/build/env/bin/supervisor --log-dir=$LOGDIR --user=hue --group=hue
