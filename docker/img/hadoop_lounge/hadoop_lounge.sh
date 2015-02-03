#!/usr/bin/env bash

HLOC_NAME=${HLOC_NAME-hl}
HLOC_IMG=${HLOC_IMG-bd4c/hadoop_lounge}

# in an interactive container discarded after use,
# with name $HLOC_NAME (default 'hl'),
# as user chimpy and with key environment vars shown,
# from image $HLOC_IMG (default 'bd4c/hadoop_local'),
# launch an interactive shell.

( docker ps -a | grep -q data_gold ) || \
  docker run --name data_gold   -v /shared/data/gold:/data/gold     bd4c/data_gold   pushpull /data/gold >> /tmp/bd4c.log
( docker ps -a | grep -q home_chimpy ) || \
  docker run --name home_chimpy -v /shared/home/chimpy:/home/chimpy bd4c/home_chimpy pushpull /home/chimpy >> /tmp/bd4c.log

exec docker run -it                       \
       --name "$HLOC_NAME"                \
       --volumes-from home_chimpy         \
       --volumes-from data_gold           \
       -v /shared/data/out:/data/out      \
       -u chimpy -w /home/chimpy          \
       -e HOME=/home/chimpy -e TERM=$TERM \
       "$HLOC_IMG"                        \
       /bin/bash -l
