# Big Data for Chimps Example Code

The first step is to clone this repo:

```
git clone --recursive http://github.com/mrflip/big_data_for_chimps-code.git bd4c-code
```

_TODO: change the git address when we move the repo_

You will now see a directory called `bd4c-code`


Everything below (apart from one quick step) should take place in the `bd4c-code/cluster/` directory. **DO NOT USE THE `bd4c-code/docker/` DIRECTORY** -- that is for generating the docker containers, and you will want to use the pre-validated ones to start off.


## Dockering I: Preliminaries

### Prerequisites

* Docker
* Boot2Docker, if you're on OSX
* Ruby with rake
* Node with npm

### Running under boot2docker

#### Port Forwarding

By forwarding selected ports from the Boot2Docker VM to the OSX host, you'll be able to ssh directly to the machines from your regular terminal window, and will be able to directly browse the various web interfaces. It's highly recommended, but you need to pause the boot2docker VM for a moment to accomplish this. Let's do that now before we dive in:

```
boot2docker down
rake docker:open_ports
```

#### You're going to need a bigger boat.

While you have the VM down, you should also increase the amount of memory you're allocating to the VM. In VirtualBox manager, select your `boot2docker-vm` and hit 'Settings'. Under the System tab, you will see the base memory slider -- adjust that to at least 4GB, but not higher than 30-50% of the physical ram on your machine.

The default 20GB virtual hard drive allocated for boot2docker will be a bit tight, but it's a pain in the butt to resize so might as well wait until it's a problem

#### `DOCKER_HOST` and `DOCKER_IP` environment variables

Bring boot2docker back up with

```
boot2docker up
```

When you run `boot2docker up`, it will either tell you that you have the env variable set already (hooray) or else tell you the env variable to set. You should not only set its value in your current terminal session, you should add it and a friend to your `.bashrc` file. The address will vary depending on circumstances, but using the current value on my machine I have added these lines:

```
export DOCKER_IP=192.168.59.103
export DOCKER_HOST=tcp://$DOCKER_IP:2375
```

The `DOCKER_IP` variable isn't necessary for docker, but it will be useful for working at the commandline -- when we refer to `$DOCKER_IP` in the following we mean just that bare IP address of the docker<->host bridge.

### Pull in the containers

The first step will be to pre-seed the containers we'll use. This is going to bring in more than 4 GB of data, so don't do this at a coffee shop, and do be patient.

```
rake docker:pull
```

You can do the next couple steps at least while that proceeds.

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

### Minor setup needed on the docker host

The namenode insists on being able to resolve the hostnames of its clients -- something that is far more complex in Dockerland than you'd think. We have a pretty painless solution, but it requires a minor intervention

On the docker host (`boot2docker ssh`, or whatever else it takes):

```
boot2docker ssh # if you're on OSX
mkdir -p /tmp/deb_proxy /tmp/bulk/hadoop
sudo touch               /var/lib/docker/hosts
sudo chmod 0644          /var/lib/docker/hosts
sudo chown nobody        /var/lib/docker/hosts
```

Leave a terminal window open on the docker host, as we'll do a couple more things over there.

### Wait until the pull completes

Don't proceed past this point until the `rake docker:pull` has succeeded. Time for some rolly-chair swordfighting!

## Dockering II: Start it Up!

### Preliminaries Complete!

You're ready to proceed when:

* Running `echo $DOCKER_HOST` from your terminal returns the address of your docker host
* Running `rake docker:pull` marches through the list fairly quickly, reporting in a bored tone that it already has everything.
* On the docker host, `ls -l /var/lib/docker/hosts` shows a file of zero size.
* Running `decking` (with no args) reports '`Version: 0.2.1-bd4c`'
* Running `docker ps -a` shows no containers running.

Alright! Now the fun starts.

### Start the helpers cluster

The helpers cluster holds the gizmo that will socialize hostnames among all the containers, so we will bring it up first.

```
rake docker:helpers
```

If everything works, these things will be true:

* Running `cat /var/lib/docker/hosts` (which was empty just moments ago!) will have all sorts of nice information in it, including an entry for 'host-filer'
* Running `docker ps` shows containers for `host_filer`

### Instantiate the data containers

First we will lay down a set of data-only containers. These wonderful little devices will make the cluster come to life fully populated with data on both the HDFS and local filesystem.

```
rake data:create
```

A torrent of filenames will fly by on the screen as the containers copy data from their internal archive onto the shared volumes the cluster will use. `data_gold`, the filesystem-local version of the data, will have directories about sports, text, airlines and ufos. `data_outd`, for output data, will be empty (that's your job, to fill it). `data_hdfs0` will be a long streak of things in `current/` with large integers in their name. The contents of `data_nn` are tiny but so-very-precious: it's the directory that makes sense of all those meaningless filenames from the data node. Lastly, the `home_chimpy` volume will have a lot of git and pig and ruby and asciidoc files. It's what you paid the big bucks for right there: the code and the book.

At this point, running `rake docker:ps` will show five containers (`data_{nn,hdfs0,gold,outd}` and `home_chimpy`), all in the stopped stated. Wait, what? Yes, these are supposed to be in the stopped state -- all they do is anchor the data through docker magic. That also means they don't appear if you run `docker ps` -- you have to run `docker ps -a` to see them.

### Ready the cluster

The next step will create the compute containers in a stopped state:

```
rake cluster:create
```

Running `rake docker:ps` will now show 12 containers: one helper, the five data containers just seen, plus

* `hadoop_lounge` -- the 'Lounge' is where you'll spend your time. It's set up with all modern conveniences: Pig, Hive, ruby/python/node, Hue (a graphical front end for the Hadoop cluster), a non-root sudo-er account named `chimpy` with password `chimpy`, and the developer tools and libraries we like to see on any professional rig.
* `hadoop_nn` -- the 'Namenode' (personified as Nannette) -- superintends the safety and distribution of data across the the cluster.
* `hadoop_rn` -- the 'Resource Manager' (personified as J.T.) -- superintends the allocation of work across the cluster. Roughly analogous to the Jobtracker from earlier versions of Hadoop.
* `hadoop_snn` -- the poorly-named secondarynamenode. This is in no way a backup for the namenode -- it exists only to perform a certain minor but essential function to assist the namenode. As long as it's running we shan't think of it again.
* `hadoop_worker` -- twelve containers running, all for the benefit of this one container that we'll make do all the work. It hosts the datanode (your elephant: stores and serves data) and node manager (your typical middle manager: seems important, but all it does is hand out job assignments to the actual task processes and reassure upper management that progress is being made).


### Start the thing:

You've laid the groundwork. You've been introduced. Now you're ready to get busy.

```
rake cluster:start
```

A set of happy little checkmarks should light up in a row, and only a few seconds later the machines should be accessible by ssh and at their various web consoles.

If things have worked, and you took our advice to set up port forwarding, you'll see the following.

#### Hue Web console.

The friendly Hue console will be available at http://DOCKER_IP:9001/ in your browser (substitute the ip address of your docker). The login and password are 'chimpy' and 'chimpy'. (Ignore any whining it does about Oozie or Pig not working -- those are just front-end components we haven't installed)

* you can ssh to the lounge with `ssh -i insecure_key.pem chimpy@$DOCKER_IP -p 9022`



#### Troubleshooting

* http://localhost:50070/dfshealth.html#tab-datanode opens an returns content (Yay the namenode is working)
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
