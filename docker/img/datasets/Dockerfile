#
# TODO -- don't use bd4c/baseimage
# (using for now so I don't have to think)
#
FROM       radial/busyboxplus:git
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

ENV  ARCHIVE /archiver/archive.git

#
# This is meant to be used as a data-only container:
# https://docs.docker.com/userguide/dockervolumes/
#
# Unfortunately, in the current version of docker (2014 Nov), you cannot pickle
# a data container's volumes with it -- they live on the host machine in a kind
# of parallel shadow universe. Help is on the way, so we have chosen the
# following workaround.
#
# This container has a directory called /archive and a directory called /data.
#
# * Run with no args is the same as '--copyonce'
# * `--force-unpack` --
# * `--create`       -- if the '.unpacked' tombstone
# * `--archive`      --

COPY img/datasets/conf/archiver.sh   /bin/
COPY img/datasets/README-archiver.md /archiver/README.md
COPY img/datasets/setup-archiver.sh  /tmp/

RUN  /tmp/setup-archiver.sh

ENTRYPOINT ["/bin/archiver.sh"]
CMD ["mirror", "/data"]
