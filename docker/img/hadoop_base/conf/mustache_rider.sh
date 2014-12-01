#!/bin/bash
set -x ; set -e ; date

export IP_ADDRESS=`getent hosts $HOSTNAME | cut -f1 -d' '`

if [ -n "$AWS_REGION" ] ; then
  set +e  # We really want this to work, but we also want the machine to start.
  #
  export ORIG_HOSTNAME=$HOSTNAME
  export AWS_HOSTNAME=$(ruby -e 'parts = ENV["IP_ADDRESS"].chomp.split(".") ; puts "ip-#{parts.join("-")}.#{ENV["AWS_REGION"]}" ')
  #
  cp -n /etc/hosts /etc/hosts.orig
  perl -pe 's/^([\d\.]+)\s+('$ORIG_HOSTNAME'.*)/\1\t'$AWS_HOSTNAME'\t\2\t\3/g;' /etc/hosts.orig > /etc/hosts.new
  cp /etc/hosts.new /etc/hosts
  #
  export HOSTNAME="$AWS_HOSTNAME"
  echo "$AWS_HOSTNAME" > /etc/hostname
  #
  set -e
fi

# listing space-separated roles in the `$IAMA` environment variable
# nominate this container itself into that role.
#
# Example:
#    IAMA="HADOOP_NN_HOSTNAME HADOOP_RM_HOSTNAME"
#    # sets HADOOP_NN_HOSTNAME and HADOOP_RM_HOSTNAME to the output of running `hostname`
#
# NN_PORT_50070_TCP_ADDR RM_PORT_8088_TCP_ADDR JT_PORT_50030_TCP_ADDR
#
for iama in $IAMA IAMA_HOSTNAME ; do
  export "${iama}=$HOSTNAME"
done 

# Dump the current env var set
echo "Environment variables associated with HADOOP|TCP|UDP|PORT|ADDR|DIR:"
env | egrep 'HADOOP|TCP|UDP|PORT|ADDR|DIR|HOSTNAME' | egrep -v 'ENV' | sort || true

hostname
uname -a
getent hosts $HOSTNAME
echo '$HOSTNAME='$HOSTNAME '$IP_ADDRESS='$IP_ADDRESS

#
# This will be run by the my_init process at container startup
#
# It uses config variables specified in Dockerfiles and delivered by container
# linking (https://docs.docker.com/userguide/dockerlinks/#environment-variables)
# to template eg. {{HADOOP_NN_HOSTNAME}} into '172.17.0.204'
# dynamically
#

for file in $HADOOP_CONF_DIR/*.xml $HUE_CONF_DIR/hue.ini ; do
  dest_file=$file
  mush_file=$file.mustache
  if [[ -f "$mush_file" ]] ; then
    echo "Taking $mush_file for a mustache ride!"
    cat $mush_file | mush > $dest_file
    colordiff -uw $mush_file $dest_file || true
  fi
done

#
# We shouldn't be doing this here.
#

mkdir -p  $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce  $HADOOP_LOG_DIR/hadoop-yarn
chmod 775 $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce 
chown yarn:hadoop  $HADOOP_LOG_DIR/hadoop-yarn
chgrp      hadoop  $HADOOP_LOG_DIR/hadoop-hdfs $HADOOP_LOG_DIR/hadoop-mapreduce

echo "Gave configuration a mustache ride on `date`" >> $HADOOP_CONF_DIR/mustache_rider.log 

