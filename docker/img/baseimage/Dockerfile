FROM phusion/baseimage:0.9.15

MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

WORKDIR /root
ENV HOME /root

ENV safe_apt_install apt-get install -y --no-install-recommends

# Using the `code/` directory in the big_data_for_chimps git repo as working directory:
#
#   Build  image     with `docker build -t ubuntu-bd4c config/ubuntu-bd4c/`
#   Test   container with `docker run --name u_bd4c_scratch -i -t ubuntu-bd4c`
#   Delete container with `docker rm    u_bd4c_scratch`

# ---------------------------------------------------------------------------
#
# Initial Tasks
#

# Figure out the IP address of docker host
RUN                                                               \
  apt-get update &&                                               \
  route -n | awk '/^0.0.0.0/ {print $2}' > /etc/docker_host_ip && \
  echo "************ Docker Host: " && cat /etc/docker_host_ip

# !!! Do we keep this, or leave it?
RUN /usr/sbin/enable_insecure_key && /etc/my_init.d/00_regen_ssh_host_keys.sh

# Basics so we can use the deb-proxy cache
COPY /img/baseimage/setup-deb_proxy.sh     /build/
RUN          /build/setup-deb_proxy.sh

# Add the apt repos we will use
COPY /img/baseimage/setup-add_apt_repos.sh /build/
RUN          /build/setup-add_apt_repos.sh

# Install and configure Java
COPY /img/baseimage/setup-java.sh          /build/
RUN          /build/setup-java.sh
ENV JAVA_HOME /usr/lib/jvm/java-7-oracle
ENV PATH      $PATH:$JAVA_HOME/bin

# Install some developer conveniences
COPY /img/baseimage/setup-add_conveniences.sh /build/
RUN          /build/setup-add_conveniences.sh

# Finish configuration
COPY /img/baseimage/setup-other_configuration.sh /build/
RUN          /build/setup-other_configuration.sh

CMD ["/sbin/my_init"]
