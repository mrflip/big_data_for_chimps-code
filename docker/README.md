

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
