#!/bin/bash
set -e ; set -x

# Hadoop Hue -- pretty front-end to hadoop
#
$safe_apt_install hue-common hue-plugins hue-server

mkdir -p        $HADOOP_LOG_DIR/hue-app
ln -snf         $HADOOP_LOG_DIR/hue-app  /var/log/hue
ln -snf         $HADOOP_LOG_DIR/hue-app  $HUE_HOME/logs

chown hue:hue   $HADOOP_LOG_DIR/hue-app

mkdir -p                                             $HUE_CONF_DIR
cp -rp                        /etc/hue/conf.empty/*  $HUE_CONF_DIR/
update-alternatives --install /etc/hue/conf hue-conf $HUE_CONF_DIR 50
update-alternatives --set                   hue-conf $HUE_CONF_DIR

/etc/my_init.d/50_hadoop_mustache_rider.sh

mkdir -p         $HUE_DATA_DIR
cp -rp /var/lib/hue/* $HUE_DATA_DIR/
mv /var/lib/hue  /var/lib/away-hue
mkdir -p         $HUE_DATA_DIR
chown -R hue:hue $HUE_DATA_DIR
chmod 700        $HUE_DATA_DIR
ln -s            $HUE_DATA_DIR /var/lib/hue

ls -l $HUE_DATA_DIR

export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
echo -e 'chimpy\nchimpy\n' | /usr/lib/hue/build/env/bin/hue createsuperuser --user=chimpy --email=y@y.com

cat > /etc/my_init.d/30_fix_hue_perms.sh <<'EOF'
#!/bin/sh
# In case the hue data dir is mounted from a volume, ensure permissions.
# Not creating the dir though, it's supposed to already be there volume or not.
chown -R hue:hue $HUE_DATA_DIR
chmod 700        $HUE_DATA_DIR
# logdirs we should make
mkdir -p         $HADOOP_LOG_DIR/hue-app
mkdir -p         $HADOOP_LOG_DIR/hue-daemon
chown hue:hue    $HADOOP_LOG_DIR/hue-app
EOF
chmod a+x /etc/my_init.d/30_fix_hue_perms.sh
