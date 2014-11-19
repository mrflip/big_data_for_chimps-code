#!/bin/bash
set -v ; set -e # talk out loud and die easy

apt-get update

$safe_apt_install graphviz
# $safe_apt_install nano procps locate # don't make me have to come over there and use these

# These are only needed for building
BUILDTIME_DEBS="git"

$safe_apt_install $BUILDTIME_DEBS

#
# Get code
#

# Clone repo into a directory with version `dev`, link it to the canonical
# named location
#
git clone https://github.com/Netflix/Lipstick.git $LIPSTICK_DIR-dev
ln -s $LIPSTICK_DIR-dev $LIPSTICK_DIR

# Work with the pig0.13 branch
cd $LIPSTICK_DIR
git checkout --track -b pig0.13 origin/pig0.13
