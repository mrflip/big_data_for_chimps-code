#!/bin/sh
set -e ; set -x  # live verbosely, die easily

# ---------------------------------------------------------------------------
#
# Add apt repositories
#

# Install apt tools
$safe_apt_install curl net-tools apt-utils software-properties-common python-software-properties 

# Java
add-apt-repository    -y ppa:webupd8team/java

# Cloudera
echo "deb [arch=amd64] http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh precise-cdh5 contrib" >  /etc/apt/sources.list.d/cloudera.list
echo "deb-src http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh precise-cdh5 contrib"          >> /etc/apt/sources.list.d/cloudera.list
echo "deb [arch=amd64] http://archive.cloudera.com/gplextras5/ubuntu/precise/amd64/gplextras precise-gplextras5 contrib" >  /etc/apt/sources.list.d/cloudera-gplextras.list
echo "deb-src http://archive.cloudera.com/gplextras5/ubuntu/precise/amd64/gplextras precise-gplextras5 contrib"                    >> /etc/apt/sources.list.d/cloudera-gplextras.list
curl -s http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh/archive.key | apt-key add -

# Adopt the new repos
apt-get --force-yes -y update

