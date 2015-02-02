#!/usr/bin/env bash

set -v ; set -e

# ORG=bd4c ; for foo in $ORG/hadoop_lounge hloc_builder ; do ln -snf ./img/`basename $foo`/Dockerfile ./Dockerfile && docker build -t $foo . || break ; done

docker run -d --name hloc_data                           \
       -v /mounted/data_gold                             \
       bd4c/data_gold                                    \
       pushpull /mounted/data_gold

docker run -d --name hloc_home                           \
       -v /mounted/home_chimpy                           \
       bd4c/home_chimpy                                  \
       pushpull /mounted/home_chimpy

docker run -d --name hloc_builder --publish 10022:22     \
       --volumes-from hloc_data --volumes-from hloc_home \
       hloc_builder

sleep 4

ssh -i ../cluster/insecure_key.pem -p 10022 root@localhost  'mkdir -p /data/gold && rsync -rlOvit /mounted/data_gold/   /data/gold/   && chown -R chimpy:admin /data/gold    && chmod -R ug+rw /data/gold'

# docker diff hloc_builder | egrep    '^../data/gold'   | cut -d/ -f1-4 | sort | uniq -c

docker commit -m "Copying /data/gold"  hloc_builder bd4c/hadoop_local

ssh -i ../cluster/insecure_key.pem -p 10022 root@localhost  '                       rsync -rlOvit /mounted/home_chimpy/ /home/chimpy/ && chown -R chimpy       /home/chimpy'

docker diff hloc_builder | egrep -v '^../(data/gold|home/chimpy)'
docker diff hloc_builder | egrep    '^../home/chimpy' | cut -d/ -f1-4 | sort | uniq -c

docker diff hloc_builder

docker commit -m "Copying /home/chimpy"  hloc_builder bd4c/hadoop_local

# for foo in hloc_builder hloc_data hloc_home ; do docker kill $foo ; docker rm -v $foo ; done

# docker kill hadoop_local; docker rm -v hadoop_local
# docker run -d --name hadoop_local --publish 9022:22 bd4c/hadoop_local
# ssh -i ../cluster/insecure_key.pem chimpy@localhost -p 9022
