#!/bin/bash
set -e ; set -v

# Hadoop Hue -- pretty front-end to hadoop
#
$safe_apt_install hue

cp -rp                        /etc/hue/conf.empty    $HUE_CONF_DIR
update-alternatives --install /etc/hue/conf hue-conf $HUE_CONF_DIR 50
update-alternatives --set                   hue-conf $HUE_CONF_DIR

/etc/my_init.d/50_hadoop_mustache_rider.sh

export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
echo -e 'chimpy\nchimpy\n' | /usr/lib/hue/build/env/bin/hue createsuperuser --user=chimpy --email=y@y.com

# Reinstall with e.g. $HUE_HOME/tools/app_reg/app_reg.py --install $HUE_HOME/apps/hbase 
$HUE_HOME/tools/app_reg/app_reg.py --remove impala
$HUE_HOME/tools/app_reg/app_reg.py --remove hbase
$HUE_HOME/tools/app_reg/app_reg.py --remove spark
$HUE_HOME/tools/app_reg/app_reg.py --remove security
$HUE_HOME/tools/app_reg/app_reg.py --remove sqoop

aptitude search hadoop hue  | sort

updatedb
