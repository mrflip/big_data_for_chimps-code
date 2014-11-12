# Big Data for Chimps Example Code

## Generating Docker containers


Clusters are defined using [decking](http://decking.io), a Node.js tool to create, manage and run clusters of Docker containers.

### Prerequisites

* Docker
* Boot2Docker, if you're on OSX
* Ruby with rake
* Node with npm

### Install decking



Install:

```
git submodule init
git submodule update
( cd vendor/decking && npm install -g )
```

You must use that version -- others will not work (lack hostname option)

From here out, everything will take place within the `docker/` directory

### If you're running under boot2docker

You'll probably want to forward the hadoop ports. We need to pause the boot2docker VM for a moment to accomplish this, so let's do that now:

```
boot2docker down
rake docker:open_ports
boot2docker up
```

When you run `boot2docker up`, make sure that you have the env variable set -- for me, it's `export DOCKER_HOST=tcp://192.168.59.103:2375` (but yours might be different).

### Pre-seed the base images

```
docker pull phusion/baseimage:0.9.15
docker pull blalor/docker-hosts:latest
```

### Minor setup needed on the docker host

On the docker host (`boot2docker ssh`, or whatever else it takes):

```
boot2docker ssh # if you're on OSX
mkdir -p /tmp/deb_proxy /tmp/bulk/hadoop
sudo touch               /var/lib/docker/hosts
sudo chmod 0644          /var/lib/docker/hosts
sudo chown nobody        /var/lib/docker/hosts
```

Leave a terminal window open on the docker host, as we'll do a couple more things over there.

### Start the helper cluster

```
rake docker:helpers
```

You will see it go build build apt apt apt for a long time.

If everything works, these things will be true:

* Running `cat /var/lib/docker/hosts` (which was empty just moments ago!) will have all sorts of nice information in it, including entries for 'host-filer' and 'deb-proxy'.
* Running `docker ps` shows containers for `host_filer.helpers` and `deb_proxy.helpers`
* Running `curl -I http://$(hostname):10000/ | grep 'Content-Length'` has an output (i.e. the deb proxy responds to an HTTP request

### Build the images

```
rake docker:build
```

Then create the cluster:

```
rake cluster:create
```

### Start the thing:

```
rake cluster:start
```

If things have worked,

* http://localhost:50070/dfshealth.html#tab-datanode opens an returns contetn (Yay the namenode is working)
* http://localhost:8088/cluster/nodes

* `docker ps` should show

```
CONTAINER ID        IMAGE                        COMMAND                CREATED             STATUS              PORTS                                                              NAMES
49dd3fe748d9        bd4c/deb_proxy:latest        "/bin/bash"            27 minutes ago      Up 27 minutes       10000/tcp                                                          prickly_bell         
679312a500aa        blalor/docker-hosts:latest   "/usr/local/bin/dock   42 minutes ago      Up 42 minutes                                                                          host_filer.helpers   
1402f23d9b21        da9ce761dafe                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          8020/tcp, 50070/tcp, 50470/tcp                                     mad_shockley         
1e05506b89e4        9adb17f09b14                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          50070/tcp, 50470/tcp, 8020/tcp                                     grave_kirch          
40e667173e6a        9adb17f09b14                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          8020/tcp, 50070/tcp, 50470/tcp                                     hopeful_darwin       
994664c60827        b5b80f1fd5e2                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          8020/tcp, 50070/tcp, 50470/tcp                                     romantic_yonath      
d12d0b71c978        d303575ad9a7                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          50470/tcp, 8020/tcp, 50070/tcp                                     elegant_yonath       
8a269c0a917d        c0694ac34979                 "/bin/sh -c /build/h   2 hours ago         Up 2 hours          50070/tcp, 50470/tcp, 8020/tcp                                     suspicious_bartik    
6845ab5c4708        blalor/docker-hosts:latest   "/usr/local/bin/dock   19 hours ago        Up 19 hours                                                                            host_filer.helper    
23d75487641b        b8141723fa03                 "/etc/squid-deb-prox   19 hours ago        Up 19 hours         443/tcp, 80/tcp, 0.0.0.0:10000->10000/tcp, 0.0.0.0:10022->22/tcp   deb_proxy.helper
```


### Utilities

`rake -P` will list all the things rake knows how to do

* `rake docker:df`         -- runs boot2docker to get the free space on the docker host
* `rake docker:rm_stopped` -- DANGEROUS -- removes all stopped containers. 
* `rake docker:rmi_all    `-- DANGEROUS -- removes all images that have no tag. Usually, these are intermediate stages of old builds and left unchecked they will buil This command will give an error message if any such are running; use the `rake docker:rm_stopped` or stop any containers first.


## Troubleshooting

### SSH access

```
ssh -i insecure_key.pem root@localhost -p 9122
```

* Client:	      9022
* Worker:	      9122
* Hue:		      9222
* Resource Manager:   9322 (manages but does not run jobs -- the new-school jobtracker)
* Namenode:	      9422 (manages but does not hold data)
* Secondary Namenode: 9522 (keeps the cluster healthy. Does *not* act as a failover namenode)


### Example job

```
hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 1 100000
```

### Datanode working?

On the worker machine:

* `elinks http://$(hostname):50075/` loads, shows you 'DataNode on'
* 


```
docker run				      \
  -p 9122:22 -p 8042:8042 -p 50075:50075      \
  -v /tmp/bulk/hadoop/log:/bulk/hadoop/log:rw \
  --link hadoop_rm:rm --link hadoop_nn:nn     \
  --rm -it bd4c/hadoop_worker		      \
  --name hadoop_worker.tmp
  
```
