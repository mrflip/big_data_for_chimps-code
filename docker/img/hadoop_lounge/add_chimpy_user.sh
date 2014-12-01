#!/bin/bash
set -x ; set -e ; date

echo "************"
echo "*"
echo "* This adds a user, named 'chimpy', with **sudo rights**, a **publicly-known ssh key**, and a **default password**"
echo "* That is widly insecure but the purpose of this cluster is to be convenient."
echo "* We depend on you to restrict access to the machine that holds these containers"
echo "*"
echo "************"

deluser chimpy || true

# Add user, set default password
adduser chimpy --uid 2000 --disabled-password --gecos "Big Chimpin,Docker,800-MIXALOT"
echo chimpy:chimpy | chpasswd

# Authorize access from the insecure_key.pem file in the repo
mkdir -p /home/chimpy/.ssh
insecure_public_key='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVmzBG5v7cO9IScGLIzlhGlHNFhXzy87VfaPzru7qnIIdQ1e9FEKvtqEws8hVixnCUdviwX5lvcMk4Ef4Tbrmj3dyF0zFtYbjiTSyl/XQlF68DQlc2sTAdHy96wJHvh7ky511tKJzzyWwSqeef4WjeVK28TqcGnq1up0S7saFO0dJh6OfDAg2cDmhyweR3VgT0vZJyrDV7hte95MBCdK+Gp7fdCyEZcWm3S1DBFaeBqHzzt/Y/njAVKbYL9TIVPum8iMg0rMiLi9ShfP+dT5Xud5Oa3dcN2OWhiDfJw5pfhFJWd44cJ/uGRwQpvNs/PNKsYABhgLlTMUH4iawhu1Xb baseimage-docker-insecure-key'
echo "$insecure_public_key" > /home/chimpy/.ssh/authorized_keys

# Enable sudoing
addgroup admin      --gid 80  || true
# Make chimpy a sudoer
usermod -a -G admin      chimpy

# Make chimppy have superuser rights on the HDFS
usermod -a -G supergroup chimpy

chown -R chimpy /home/chimpy
