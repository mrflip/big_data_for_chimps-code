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
* Ruby 
* Basic comfort pasting things into a terminal window and hitting enter.

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

### Install the script dependencies

We'll need a couple common dependencies for the scripts we'll use. Using a reasonably modern version of ruby (> 1.9.2, > 2.0 preferred):

```
gem install bundler
bundler install
rake ps
```

If your ruby environment is good, the last command will give similar output to running `docker ps -a`.

### Pull in the containers

The first step will be to pre-seed the containers we'll use. This is going to bring in more than 4 GB of data, so don't do this at a coffee shop, and do be patient.

```
rake images:pull
```

You can do the next step while that proceeds.

### Minor setup needed on the docker host

The namenode insists on being able to resolve the hostnames of its clients -- something that is far more complex in Dockerland than you'd think. We have a pretty painless solution, but it requires a minor intervention

On the docker host (`boot2docker ssh`, or whatever else it takes):

```
boot2docker ssh                          # or however you get onto the docker host
mkdir -p          /tmp/bulk/hadoop       # view all logs there
sudo touch        /var/lib/docker/hosts  # so that docker-hosts can make container hostnames resolvable
sudo chmod 0644   /var/lib/docker/hosts
sudo chown nobody /var/lib/docker/hosts
```

Leave a terminal window open on the docker host, as we'll do a couple more things over there.

### Wait until the pull completes

Don't proceed past this point until the `rake images:pull` has succeeded. Time for some rolly-chair swordfighting!

## Dockering II: Start it Up!

### Preliminaries Complete!

You're ready to proceed when:

* Running `echo $DOCKER_HOST` from your terminal returns the address of your docker host
* Running `rake images:pull` marches through the list fairly quickly, reporting in a bored tone that it already has everything.
* On the docker host, `ls -l /var/lib/docker/hosts` shows a file of zero size.
* Running `decking` (with no args) reports '`Version: 0.2.1-bd4c`'
* Running `rake ps` shows no containers running.

Alright! Now the fun starts.

### Start the helpers cluster

The helpers cluster holds the gizmo that will socialize hostnames among all the containers, so we will bring it up first.

```
rake helpers:run
```

If everything works, these things will be true:

* Running `cat /var/lib/docker/hosts` (which was empty just moments ago!) will have all sorts of nice information in it, including an entry for 'host-filer'
* Running `rake ps` shows containers for `host_filer` and nothing else

### Instantiate the data containers

First we will lay down a set of data-only containers. These wonderful little devices will make the cluster come to life fully populated with data on both the HDFS and local filesystem.

```
rake data:create show_output=true
```

A torrent of filenames will fly by on the screen as the containers copy data from their internal archive onto the shared volumes the cluster will use. `data_gold`, the filesystem-local version of the data, will have directories about sports, text, airlines and ufos. `data_outd`, for output data, will be empty (that's your job, to fill it). `data_hdfs0` will be a long streak of things in `current/` with large integers in their name. The contents of `data_nn` are tiny but so-very-precious: it's the directory that makes sense of all those meaningless filenames from the data node. Lastly, the `home_chimpy` volume will have a lot of git and pig and ruby and asciidoc files. It's what you paid the big bucks for right there: the code and the book.

At this point, running `rake ps` will show five containers, all in the stopped stated. Wait, what? Yes, these are supposed to be in the stopped state -- all they do is anchor the data through docker magic. That also means they don't appear if you run `docker ps` -- you have to run `docker ps -a` to see them (that's why we tell you to run `rake ps`, which includes this flag by default).

### Run the cluster

You've laid the groundwork. You've been introduced. Now you're ready to run the compute containers:

```
rake hadoop:run
```

Running `rake ps` will now show 12 containers: one helper, the five data containers just seen, plus

* `hadoop_lounge` -- the 'Lounge' is where you'll spend your time. It's set up with all modern conveniences: Pig, Hive, ruby/python/node, Hue (a graphical front end for the Hadoop cluster), a non-root sudo-er account named `chimpy` with password `chimpy`, and the developer tools and libraries we like to see on any professional rig.
* `hadoop_nn` -- the 'Namenode' (personified as Nannette) -- superintends the safety and distribution of data across the the cluster.
* `hadoop_rn` -- the 'Resource Manager' (personified as J.T.) -- superintends the allocation of work across the cluster. Roughly analogous to the Jobtracker from earlier versions of Hadoop.
* `hadoop_snn` -- the poorly-named secondarynamenode. This is in no way a backup for the namenode -- it exists only to perform a certain minor but essential function to assist the namenode. As long as it's running we shan't think of it again.
* `hadoop_worker` -- twelve containers running, all for the benefit of this one container that we'll make do all the work. It hosts the datanode (your elephant: stores and serves data) and node manager (your typical middle manager: seems important, but all it does is hand out job assignments to the actual task processes and reassure upper management that progress is being made).

#### Hue Web console.

The friendly Hue console will be available at http://DOCKER_IP:9001/ in your browser (substitute the ip address of your docker). The login and password are 'chimpy' and 'chimpy'. (Ignore any whining it does about Oozie or Pig not working -- those are just front-end components we haven't installed)

* Visit the File Browser and drill down to http://$DOCKER_IP:9001/filebrowser/#/data/gold  You'll see all the different datasets we'll use. There's lots of fun stuff in there -- finishing the book will leave you ready to design your own investigations, and so we've provided lots of territory to explore.
* Visit the Job Browser. Nothing going on yet, of course, but you'll be back here in a moment.

#### SSH terminal access

You will also spend some time commanding a terminal directly on the machine. Even if you're not one of the many people who prefer the commandline way, in the later chapters you'll want to peek under the covers of what's going on within each of the machines. SSH across by running

```
ssh -i insecure_key.pem chimpy@$DOCKER_IP -p 9022
```

All of the nodes in the cluster are available for ssh. Using the normal SSH port of 22 as a mnemonic, we've set each container up in ascending centuries:

* Lounge:	      9022
* Worker:	      9122
* Resource Manager:   9322 (manages but does not run jobs -- the new-school jobtracker)
* Namenode:	      9422 (manages but does not hold data)
* Secondary Namenode: 9522 (keeps the namenode healthy. Does *not* act as a failover namenode)

9222 is reserved for a second worker, if you have the capacity.

#### The dangerous thing we did that you need to know about

We've done something here that usually violates taste, reason and safety: the private key that controls access to the container is available to anyone with a browse. To bring that point home, the key is named `insecure_key.pem`. Our justification is that these machines are (a) designed to work within the private confines of a VM, without direct inbound access from the internet, and (b) are low-stakes playgrounds with only publicly redistributable code and data sets. If either of those assumptions becomes untrue -- you are pushing to the docker cloud, or using these machines to work with data of your own, or whatever -- then we urge you to construct new private/public keypairs specific _only_ to each machine, replacing the `/root/.ssh/authorized_keys` and `/home/chimpy/.ssh/authorized_keys` files. (It's those latter files that grant access; the existing key must be removed and a new one added to retain access.) It's essential that any private keys you generate be unique to these machines: it's too easy to ship a container to the wrong place or with the wrong visibility at the current maturity of these tools. So don't push in the same key you use for accessing work servers or github or docker or the control network for your secret offshore commando HQ. 

## I WANT TO SEE DATA GO, YOU PROMISED

Right you are. There's tons of examples in the book, of course, but let's make some data fly now and worry about the details later.

### See pig in action

On hadoop:

```
cd book/code/
  # This file isn't on the HDFS right now, so put it there:
hadoop fs -mkdir -p /data/gold/geo/ufo_sightings
hadoop fs -put      /data/gold/geo/ufo_sightings/ufo_sightings.tsv.bz2 /data/gold/geo/ufo_sightings/ufo_sightings.tsv.bz2
  # Run, pig, run!
pig -x mapred 04-intro_to_pig/a-ufo_visits_by_month.pig
  # See the output:
hadoop fs -cat /data/outd/ufos/sightings_hist/\* > /tmp/sightings_hist.tsv
  # Whadday know, they're the same!
colordiff -uw /data/outd/ufos/sightings_hist-reference.tsv /tmp/sightings_hist.tsv | echo 'No diffference'
```

Locally!

```
  # execute all examples from the code directory (i.e. not the one holding the file)
  # also note that at this moment you are running someting in ~book/code (book repo) and not ~/code
cd book/code
  # Need to remove the output directory -- check that there's nothing in it, then remove it
ls /data/outd/ufos/sightings_hist 
rm -rf /data/outd/ufos/sightings_hist
  # Run, pig, run
pig -x local 04-intro_to_pig/a-ufo_visits_by_month.pig 
   # Look ma, just what we predicted!
colordiff -uw /data/outd/ufos/sightings_hist{-reference.tsv,/part*} | echo 'No diffference'
```

## Troubleshooting

The rake tasks are just scripts around the `docker` command, and print each command they execute before running them, and again afterwards if the command failed.


### Checklist

#### Is the 

#### Are the data volumes in place?


#### Is the namenode working?

* http://localhost:50070/dfshealth.html#tab-datanode opens an returns content (Yay the namenode is working)
* http://localhost:8088/cluster/nodes

* `rake ps` should show



### Datanode working?

On the worker machine:

* `elinks http://$(hostname):50075/` loads, shows you 'DataNode on'


## Troubleshooting


### Example Straight-Hadoop job

If the machines seem to be working, and the daemons seem to be running, this is a test of whether Hadoop works

```
hadoop jar /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 1 100000
```



## Docker stuff

`rake -P` will list all the things rake knows how to do

* `rake docker:df`         -- runs boot2docker to get the free space on the docker host
* `rake docker:rm_stopped` -- DANGEROUS -- removes all stopped containers.
* `rake docker:rmi_blank`  -- DANGEROUS -- removes all images that have no tag. Usually, these are intermediate stages of old builds and left unchecked they will buil This command will give an error message if any such are running; use the `rake docker:rm_stopped` or stop any containers first.



```
    docker run				      \
      -p 9122:22 -p 8042:8042 -p 50075:50075      \
      -v /tmp/bulk/hadoop/log:/bulk/hadoop/log:rw \
      --volumes-from /data_hdfs0                  \
      --link hadoop_rm:rm --link hadoop_nn:nn     \
      --rm -it bd4c/hadoop_worker		      \
      --name hadoop_worker.tmp

```
