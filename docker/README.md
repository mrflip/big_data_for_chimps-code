

	cd /Users/flip/ics/book/big_data_for_chimps/examples/docker/
	ORG=bd4c ; for foo in $ORG/baseimage $ORG/hadoop_base $ORG/hadoop_nn $ORG/hadoop_snn $ORG/hadoop_lounge $ORG/hadoop_hue $ORG/hadoop_rm $ORG/hadoop_worker $ORG/hadoop_lounge hloc_builder ; do ; ln -snf ./img/`basename $foo`/Dockerfile ./Dockerfile && docker build -t $foo . || break ; done

### Install decking

Clusters are defined using [decking](http://decking.io), a Node.js tool to create, manage and run clusters of Docker containers, as well as some rake scripts we've assembled.

Install:

```
  # do this from the top-level of the repo
cd bd4c-code
git submodule init
git submodule update
  # vendor/decking should now have contents
ls vendor/decking
  # letting you perform the install
( cd vendor/decking && npm install -g )
  # go back to the docker playspace
cd cluster/ 
```

You must use _only the version given_ -- the npm remote one will not work.

### Helpful tweaks to the boot2docker docker host

Helpful tools:

```
tce-load -wi nano.tcz
```

### ...

```
tail -F -n 10000 /bulk/log/hadoop/namenode-daemon/current
```


### Runnable

```
export DF_DIR=$PWD/code/config

( cd $DF_DIR; docker stop deb-proxy ; docker build -t $ctr ./$ctr && docker rm $ctr && docker run --name $ctr --rm -v /tmp/deb-proxy:/deb-proxy -p 8000:8000 $ctr )

( cd $DF_DIR ; docker build -t ubuntu-bd4c ./ubuntu-bd4c )

for ctr in hadoop-base hadoop-client hadoop-pseudo ; do echo "====== $ctr" ; ( cd $DF_DIR ; docker build -t $ctr ./$ctr ) ; done
docker --rm --name hdp -i -t hadoop-client
```


### Data files

The data files are managed as a [Data Volume Container](https://docs.docker.com/userguide/dockervolumes/).

sudo docker run -d -v /dbdata --name dbdata training/postgres echo Data-only container for postgres

sudo docker run -d --volumes-from dbdata --name db1 training/postgres


### Notes

https://docs.docker.com/articles/dockerfile_best-practices/

* use a .dockerignore https://docs.docker.com/reference/builder/#the-dockerignore-file file to exclude .git dirs.

	RUN apt-get clean
	RUN apt-get purge



	# Expose port 80
	EXPOSE 80

	# use env vars to set versions globally
	ENV PG_MAJOR 9.3
	ENV PG_VERSION 9.3.4

	# and pin packages with explicit versions
	package-foo=1.3.*

	# For installing a tarball:
	RUN mdkir -p /usr/src/things \
	    && curl -SL http://example.com/big.tar.gz \
	    | tar -xJC /usr/src/things \
	    && make -C /usr/src/things all


* end entrypoint scripts with `exec "$@"`

* use `gosu` -- https://github.com/tianon/gosu -- not `sudo`


debian:wheezy

### More notes

Failed experiment:

```
  # docker run -d -p 172.17.42.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker
  skydns:
    image:        "crosbymichael/skydns"
    port:         ["172.17.42.1:53:53/udp"]
    extra:        "-nameserver 8.8.8.8:53 -domain bd4c"
  #
  # docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment dev -s /docker.sock -domain docker -name skydns
  skydock:
    image:        "crosbymichael/skydock"
    mount:        ["/var/run/docker.sock:/docker.sock"]
    extra:        "-ttl 30 -environment dev -s /docker.sock -domain docker -name skydns"
```
