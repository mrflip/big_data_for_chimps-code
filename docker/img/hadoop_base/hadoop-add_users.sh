#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Hadoop Daemon Users
#

# add daemon users -- stabilize user IDs so that we can persist data dirs
adduser hadoop      --uid 901 --group --system
adduser hdfs        --uid 902 --group --system && usermod -a -G hadoop hdfs
adduser mapred      --uid 903 --group --system && usermod -a -G hadoop mapred
adduser yarn        --uid 904 --group --system && usermod -a -G hadoop yarn
adduser hive        --uid 905 --group --system
adduser zookeeper   --uid 906 --group --system

# users in this group have root-ish rights on the hdfs
addgroup supergroup --gid 900

usermod -a -G supergroup hdfs
usermod -a -G supergroup yarn
usermod -a -G supergroup mapred

# Enable sudoing
addgroup admin      --gid 80

adduser chimpy --uid 2000 --disabled-password --gecos "Big Chimpin,Docker,800-MIXALOT"
echo chimpy:chimpy | chpasswd
usermod -a -G supergroup chimpy
usermod -a -G admin      chimpy

sudo -u chimpy mkdir /home/chimpy/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVmzBG5v7cO9IScGLIzlhGlHNFhXzy87VfaPzru7qnIIdQ1e9FEKvtqEws8hVixnCUdviwX5lvcMk4Ef4Tbrmj3dyF0zFtYbjiTSyl/XQlF68DQlc2sTAdHy96wJHvh7ky511tKJzzyWwSqeef4WjeVK28TqcGnq1up0S7saFO0dJh6OfDAg2cDmhyweR3VgT0vZJyrDV7hte95MBCdK+Gp7fdCyEZcWm3S1DBFaeBqHzzt/Y/njAVKbYL9TIVPum8iMg0rMiLi9ShfP+dT5Xud5Oa3dcN2OWhiDfJw5pfhFJWd44cJ/uGRwQpvNs/PNKsYABhgLlTMUH4iawhu1Xb baseimage-docker-insecure-key' \
  | sudo -u chimpy tee /home/chimpy/.ssh/authorized_keys > /dev/null
