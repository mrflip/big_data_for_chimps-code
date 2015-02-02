#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Developer Conveniences
#

echo "======== begin " ;

du --exclude=proc -smc / ; echo "======== basics " ; 

# commandline tools we want on any machine we'll have to debug (~ 71MB)
$safe_apt_install                                         \
  aptitude colordiff elinks git host less locate man nano \
  dstat htop ifstat netcat-openbsd nmap openssl rsync     \
  sudo tar tree unzip vim wget zip 

## The rest of this we can kick to the client install later

du --exclude=proc -smc / ; echo "======== build"

# for building packages (~96 MB)
$safe_apt_install                                                 \
  build-essential autoconf automake1.9 libtool make gcc

du --exclude=proc -smc / ; echo "======== libs"

# libs (~ 25 MB)
$safe_apt_install                                                 \
  libcurl4-openssl-dev libidn11-dev libreadline6 libreadline6-dev \
  libssl-dev  libxml2-dev libxml2-dev libxml2-utils libxslt-dev   \
  libxslt1-dev libxslt1-dev libyaml-dev libyaml-dev zlib1g-dev

du --exclude=proc -smc / ; echo "======== java"

$safe_apt_install                                                 \
        ant maven2 scala 

du --exclude=proc -smc / ; echo "======== python"

# python (~ 80MB)
$safe_apt_install python3 python3-dev python-dev python-setuptools

du --exclude=proc -smc / ; echo "======== emacs"

# emacs (~ 80MB)
$safe_apt_install emacs23-nox

du --exclude=proc -smc / ; echo "======== node"

# node (~ 8 MB)
$safe_apt_install nodejs

du --exclude=proc -smc / ; echo "======== ruby"

# ruby (~ 27 MB)
$safe_apt_install ruby2.0

#
# workarounds for idiocy of current debian/ubuntu Ruby packages
#
# make ruby 2.0 the default ruby (https://bugs.launchpad.net/ubuntu/+source/ruby2.0/+bug/1310292)
for i in erb gem irb rake rdoc ri ruby testrb ; do
  sudo ln -sf /usr/bin/${i}2.0 /usr/bin/${i}
done
# make gem defaults to not installing heavy-weight docs on system gems
echo "gem: --no-ri --no-rdoc" > /etc/gemrc
# system-wide rake and bundler
gem2.0 install rake bundler --no-rdoc --no-ri
# Make those gems run under the ruby you have not the ruby they were first
# installed with: essential for people testing under multiple ruby versions
sed -i 's|/usr/bin/env ruby.*$|/usr/bin/env ruby|; s|/usr/bin/ruby.*$|/usr/bin/env ruby|' \
	/usr/local/bin/rake /usr/local/bin/bundle /usr/local/bin/bundler

du --exclude=proc -smc / ; echo "======== apt-get clean"

apt-get clean

du --exclude=proc -smc / ; echo "======== done"
