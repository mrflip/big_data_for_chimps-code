#!/usr/bin/env bash

HLOC_NAME=${HLOC_NAME-hl}
HLOC_IMG=${HLOC_IMG-bd4c/hadoop_local}

# in an interactive container discarded after use,
# with name $HLOC_NAME (default 'hl'),
# as user chimpy and with key environment vars shown,
# from image $HLOC_IMG (default 'bd4c/hadoop_local'),
# launch an interactive shell.

exec docker run -it                       \
       --name hadoop_local                \
       -u chimpy -w /home/chimpy          \
       -e HOME=/home/chimpy -e TERM=$TERM \
       bd4c/hadoop_local                  \
       /bin/bash -l
