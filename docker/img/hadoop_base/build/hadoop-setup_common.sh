#!/bin/sh
set -e ; set -x

echo "**********" ; du --exclude=proc -smc /

# ---------------------------------------------------------------------------
#
# Configure Hadoop
#

# Install, forcing use of the cloudera repos (so that ubuntu zookeeper isn't preferred)
$safe_apt_install -t precise-cdh5.2 hadoop zookeeper zookeeper-native

# ---------------------------------------------------------------------------
#
# Configure Hadoop
#

# Get our own set of conf files
cp -rp  /etc/hadoop/conf.empty $HADOOP_CONF

# Make those the default conf files
update-alternatives --install /etc/hadoop/conf hadoop-conf $HADOOP_CONF 50
update-alternatives --set                      hadoop-conf $HADOOP_CONF

# Make the Hadoop directories
mkdir -p            $HADOOP_PERM_DIR $HADOOP_LOCL_DIR
mkdir -p            $HADOOP_LOG_DIR  $HADOOP_TMP_DIR
chown hadoop:hadoop $HADOOP_LOG_DIR  $HADOOP_TMP_DIR
chmod 0775          $HADOOP_LOG_DIR  $HADOOP_TMP_DIR

# cleanup

aptitude search hadoop | sort
echo $PERM_DIR $LOCL_DIR $LOG_DIR $HADOOP_PERM_DIR $HADOOP_LOG_DIR $HADOOP_TMP_DIR


echo "**********" ; du --exclude=proc -smc /
