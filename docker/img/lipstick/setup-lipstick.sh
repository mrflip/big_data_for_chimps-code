#!/bin/bash
set -x ; set -e ; date # talk out loud and die easy

#
# Build
#

# How we doin'?
env | egrep 'JAVA|LIPSTICK'

echo -e "\n♫ gradle gradle gradle I made you out of clay ♪\n"
cd $LIPSTICK_DIR

# Have to build console from pig0.13
#
git checkout pig0.13
./gradlew :lipstick-console:allJars

# And have to build server from master...
#
git checkout master
./gradlew :lipstick-server:war

#
# Post-build fixup
#

echo -e "\n♪ And when we are done gradling with lipstick I shall play ♬\n" 

# fail if the jar isn't there (because eg. version changed under us)
ls -l $LIPSTICK_CONSOLE_LIBS
test -f $LIPSTICK_CONSOLE_LIBS/lipstick-console-$LIPSTICK_VERSION.jar

( set -e ; cd $LIPSTICK_CONSOLE_LIBS/ ; 
  for flavor in -full.jar .jar -withHadoop.jar -withPig.jar ; do
    ln -s ./lipstick-console-${LIPSTICK_VERSION}${flavor} ./lipstick-console$flavor
  done )

# # Make the run-app task doesn't rebuild the entire universe, jeezum crow a build
# # tool is there to define a dependency tree so if I haven't changed a file then
# # there's nothing to rebuild, I know make is a pain but we've lost something
# #
# grep "task('run-app'" $LIPSTICK_DIR/build.gradle
# perl -pi -e "s/task\\(.run-app..*/task\\(\'run-app\', type:JavaExec\\) \\{/" $LIPSTICK_DIR/build.gradle
# grep "task('run-app'" $LIPSTICK_DIR/build.gradle

# The hosts and port number are set in the lipstick.sh
#
cat > /etc/lipstick.properties.mustache <<EOF
lipstick.index     = lipstick
cluster.name       = lipstick_cluster
discovery.type     = list
elasticsearch.urls = {{ES_PORT_9300_TCP_ADDR}}
transport.tcp.port = {{ES_PORT_9300_TCP_PORT}}
EOF

# # Since we are still in the same docker step, cleaning up after ourselves _does_
# # save docker image space.
# #
# df
# 
# apt-get clean
# # rm -rf /var/lib/apt/lists/*
# ls -l /var/lib/apt/lists/*
# apt-get remove -y --purge --auto-remove $BUILDTIME_DEBS
# apt-get autoremove
# rm -rf /root/.gradle*
# 
# df
