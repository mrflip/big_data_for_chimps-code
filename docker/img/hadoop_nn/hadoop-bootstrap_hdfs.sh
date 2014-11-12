#!/bin/sh
set -e ; set -x

echo "Hadoop environment variables: "
env | grep HADOOP

# force templating so that we can format the namenode.
#
HADOOP_NN_HOSTNAME=$HOSTNAME /etc/my_init.d/50_hadoop_mustache_rider.sh
diff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml || true
diff -uw $HADOOP_CONF_DIR/hdfs-site.xml.mustache $HADOOP_CONF_DIR/hdfs-site.xml || true

# Format the HDFS
#
sudo -u hdfs hdfs namenode -format

# Start the namenode. We can make dirs without any dns running.
/etc/sv/hadoop_nn/run | tee /tmp/nn_startup_log 2>&1 &
# Note: starting it this way is sketchy, but runit isn't enabled yet so we can't
# properly start the service.

# Can't use hdfs dfsadmin -safemode wait -- that needs to connect to the namenode!
# So we poll the loks. like we said, sketchy.
until grep 'namenode.NameNode: NameNode RPC up' /tmp/nn_startup_log ; do
  echo "Waiting for namenode to start... `date`" ; sleep 1
done
echo "Assuming namenode has started... `date`"

sudo -u hdfs hadoop fs -mkdir -p /tmp /user/root $HADOOP_LOG_DIR/yarn-apps $HADOOP_BULK_DIR/yarn-staging/history/done_intermediate

sudo -u hdfs hadoop fs -chmod -R 1777     /tmp

sudo -u hdfs hadoop fs -chown root        /user/root

sudo -u hdfs hadoop fs -chown yarn:mapred $HADOOP_LOG_DIR/yarn-apps

sudo -u hdfs hadoop fs -chmod 1777        $HADOOP_BULK_DIR/yarn-staging
sudo -u hdfs hadoop fs -chmod -R 1777     $HADOOP_BULK_DIR/yarn-staging/history/done_intermediate
sudo -u hdfs hadoop fs -chown -R mapred   $HADOOP_BULK_DIR/yarn-staging

sudo -u hdfs hadoop fs -ls -R /

