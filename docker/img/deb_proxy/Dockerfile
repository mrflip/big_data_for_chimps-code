FROM phusion/baseimage:0.9.15
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney; original by Panagiotis Moustafellos <pmoust@gmail.com>
WORKDIR /root

EXPOSE 10000
VOLUME ["/bulk/deb_proxy"]

ENV safe_apt_install apt-get install -y --no-install-recommends

ENV DEB_PROXY_LOG_DIR    /bulk/deb_proxy/log
ENV DEB_PROXY_CACHE_DIR  /bulk/deb_proxy/cache
ENV DEB_PROXY_CONF_FILE  /etc/squid-deb-proxy/squid-deb-proxy.conf

# install squid-deb-proxy
RUN apt-get update && $safe_apt_install squid-deb-proxy 

# Config files ; Extra locations to cache from ; starter script
COPY ./img/deb_proxy/squid-deb-proxy.conf ${DEB_PROXY_CONF_FILE}.new
COPY ./img/deb_proxy/extra-sources.acl    /etc/squid-deb-proxy/mirror-dstdomain.acl.d/20-extra-sources.acl.new
COPY ./img/deb_proxy/start.sh             /etc/squid-deb-proxy/start.sh

RUN \
  echo 0.0.0.0/32 >> /etc/squid-deb-proxy/allowed-networks-src.acl.d/10-default && \
  mkdir -p /bulk/deb_proxy/log /bulk/deb_proxy/cache && \
  cp ${DEB_PROXY_CONF_FILE} ${DEB_PROXY_CONF_FILE}.orig && \
  ln -snf ${DEB_PROXY_CONF_FILE}.new ${DEB_PROXY_CONF_FILE} && \
  chmod +x /etc/squid-deb-proxy/start.sh 

# !!! Do we keep this, or leave it?
RUN /usr/sbin/enable_insecure_key && /etc/my_init.d/00_regen_ssh_host_keys.sh
  
ENTRYPOINT ["/etc/squid-deb-proxy/start.sh"]


