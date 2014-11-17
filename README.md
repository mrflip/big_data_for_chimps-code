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
bundle install
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
colordiff -uw /data/outd/ufos/sightings_hist-reference.tsv /tmp/sightings_hist.tsv && echo 'No diffference'
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
colordiff -uw /data/outd/ufos/sightings_hist{-reference.tsv,/part*} && echo 'No diffference'
```

## Troubleshooting

The rake tasks are just scripts around the `docker` command, and print each command they execute before running them, and again afterwards if the command failed.


### Checklist

#### Is your commandline environment complete and correct?

Check that you know where you are:

* `git remote show origin` shows something like `https://github.com/infochimps-labs/big_data_for_chimps-code.git` (actually right now it's at `https://github.com/mrflip/big_data_for_chimps-code.git`)
* `git fetch --all origin` succeeds.
* `git diff origin/master` shows no unexplained differences
* `git log` shows the same commits that visiting the code repo's github page does.
* `pwd` shows a directory that ends in `cluster`, a subdirectory of the repo you cloned.

check that docker is happy:

* Running `boot2docker up` tells you that all your environment variables are happy. (It's safe to run this more than once)
* Running `echo $DOCKER_HOST` from your terminal returns the address of your docker host
* Running `docker ps` shows a first line reading `CONTAINER ID   IMAGE     COMMAND ...`

Check that ruby is happy:

* `ruby --version` shows `1.9.2` or more recent (preferably `2.something`). If not, consult the internet for instructions on installing ruby.

Check that your gems are installed correctly:

* `bundle --version` shows `1.7.6` or better. If not, run `gem install bundler`.
* `git status` shows no differences in Gemfile or Gemfile.lock from the mainline repo. If not, check out an unchanged version and run `bundle install` (and not, for example, `bundle update`)
* `bundle install` shows a bunch of lines saying 'Using ...' (not 'Installing ...') and finishes with 'Your bundle is complete!'.
* `rake --version` completes and shows `10.3` or better.

Check that rake and the rakefile are basically sane:

* `rake -T` returns content like

   ```
   rake data:create[container]       # Create the given container, or all in the data cluster with data:create[all]
   rake data:delete_data[container]  # Removes the given containers, or all in the data cluster with data:delete_data[all]
   rake df                           # Uses boot2docker to find the disk free space of the docker host
   rake hadoop:rm[container]         # Remove the given container, or all in the hadoop cluster with hadoop:rm[all]
   ```

* `rake ps` shows the same basic info as `docker ps`.

#### Do you have the right images?

* Running `rake images:pull` marches through the list fairly quickly, reporting in a bored tone that it already has everything.

* `docker images` shows something like:

  ```
    6     bd4c/baseimage          latest          1130650140        1.053 GB      024867a51a963   26 hours ago            -
    9     bd4c/data_gold          latest           515584819        491.7 MB      419705640c68d   28 hours ago            -
   19     bd4c/data_hdfs0         latest           322227404        307.3 MB      503690dc75293   39 hours ago            -
    7     bd4c/data_hue           latest            92536832        88.25 MB      054799fcb4bea   27 hours ago            -
   15     bd4c/data_nn            latest            96720650        92.24 MB      6431a7bc41c16   33 hours ago            -
   12     bd4c/data_outd          latest            92327116        88.05 MB      798c7aea9b31b   28 hours ago            -
    5     bd4c/hadoop_base        latest          1314259992        1.224 GB      4f6e4def7638f   26 hours ago            -
    0     bd4c/hadoop_lounge      latest          1900523028         1.77 GB      e4176c0a41572   26 hours ago            -
    4     bd4c/hadoop_nn          latest          1318554959        1.228 GB      2701a8c4dbda1   26 hours ago            -
    3     bd4c/hadoop_rm          latest          1317481218        1.227 GB      509a118c6b911   26 hours ago            -
    2     bd4c/hadoop_snn         latest          1317481218        1.227 GB      f8b74aecb6927   26 hours ago            -
    1     bd4c/hadoop_worker      latest          1319628701        1.229 GB      17465e5f6811e   26 hours ago            -
   13     bd4c/home_chimpy        latest           225234124        214.8 MB      e2b36f311e76a   28 hours ago            -
   20     bd4c/volume_boxer       latest            92316631        88.04 MB      b62e15f22f9d8   42 hours ago            -
   34     blalor/docker-hosts     latest           345400934        329.4 MB      98e7ca605530c   3 months ago            -
   27     phusion/baseimage       0.9.15           303457894        289.4 MB      cf39b476aeec4   6 weeks ago             -
   33     radial/busyboxplus      git               13484687        12.86 MB      30326056bb14d   8 weeks ago             -
  ```

#### Is the helpers cluster running?

* Running `rake ps` shows a `host_filer` container, with status of 'Up (some amount of time)
* On the docker host, `cat /var/lib/docker/hosts` has entries for 'host-filer' and all other containers you expect to be running; and those entries match

If not, the docker-hosts project is at https://github.com/blalor/docker-hosts

**Citizens of the future**: it's quite likely that docker has evolved a superior solution to the hostnames problem, and so this may be the cause and not solution of a conflict.

If you can't get the helpers cluster running correctly, you can instead update the `/etc/hosts` file on each container.

Here is what mine looks like right now, with a single worker running:

```
127.0.0.1	localhost	localhost4
172.17.0.107	host-filer
172.17.0.119	nn
172.17.0.120	snn
172.17.0.121	rm
172.17.0.122	worker00
172.17.0.123	lounge
::1	localhost	localhost6	ip6-localhost	ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
```

Those will **not be the actual IP addresses** -- there are instructions for finding them, below.

What matters most is that on the namenode, all worker IPs resolve to hostnames and vice-versa:

```
chimpy@nn:~$ getent hosts 172.17.0.122
172.17.0.122    worker00
chimpy@nn:~$ getent hosts worker00
172.17.0.122    worker00
chimpy@nn:~$ getent hosts google.com
173.194.115.73  google.com
173.194.115.69  google.com
```

#### Are the data volumes in place?

* `rake info[all,volumes]` should show at least these six volumes, in a stopped state:
  
  ```
  name                    state   ip_address      hostname        image_name              volumes
  data_gold               stopped                                 bd4c/data_gold          /data/gold
  data_outd               stopped                                 bd4c/data_outd          /data/outd
  data_hue                stopped                                 bd4c/data_hue           /bulk/hadoop/hue
  data_nn                 stopped                                 bd4c/data_nn            /bulk/hadoop/name
  data_hdfs0              stopped                                 bd4c/data_hdfs0         /bulk/hadoop/hdfs
  home_chimpy             stopped                                 bd4c/home_chimpy        /home/chimpy
  ```

Is the correct data present?

* Running `rake data:inspector` will run a machine that mounts all volumes in the data cluster
* On the inspector node, running `du -sm /data/gold /data/outd /bulk/hadoop/{hue,name,hdfs} /home/chimpy` returns

  ```
  386	/data/gold
  1	/data/outd
  1	/bulk/hadoop/hue
  5	/bulk/hadoop/name
  210	/bulk/hadoop/hdfs
  124	/home/chimpy
  ```

These totals will probably have changed somewhat since the last edit of the readme, but the relative sizes should resemble the above

#### Access the lounge

* SSH to the machine from your host using `ssh -i insecure_key.pem -p 9422 root@namenode_ip_address` should work. If not, try it from the docker host: 
  - Note the ip_address shown in `rake info`
  - copy the contents of `insecure_key.pem` to the same-named file on the docker host.
  - Visit the docker host machine (`boot2docker ssh` or whatever)
  - From there, run `ssh -i insecure_key.pem -p 9422 root@ip_address_shown_above`

* Listing the HDFS directory with `hadoop fs -ls /` should show several directories, including `/tmp`, `/user` and `/data`.
  - Running `hadoop fs -du /data` should show many megabytes of usage
* Copying a new file onto the HDFS with `hadoop fs -cp /etc/passwd ./file.txt` should succeed
* Displaying that file with `hadoop fs -cat ./file.txt` should show what you copied

* Listing the running jobs with `hadoop jobs

* The cluster should have active 

  ```
  chimpy@nn:~$ mapred job -list-active-trackers
  14/11/16 05:56:09 INFO client.RMProxy: Connecting to ResourceManager at rm/172.17.0.162:8032
  tracker_worker00:37823
  ```

#### Is the HDFS working?

* The cluster should be **out** of safemode: `hdfs dfsadmin -safemode get` should report `Safe mode is OFF`.

* The HDFS report from  `hdfs dfsadmin -report` should show
  - the expected number of datanodes,
  - no missing, corrupt or under-replicated blocks,
  - a healthy amount of DFS space remaining
  - the amount of DFS used should match the size of the contents of the HDFS

The direct namenode console at http://$DOCKER_IP:50070/dfshealth.html#tab-overview should open and returns content. If so, the namenode is working and you can access it.

```
Safemode is off.
92 files and directories, 69 blocks = 161 total filesystem object(s).
Heap Memory used 96.32 MB of 160.5 MB Heap Memory. Max Heap Memory is 889 MB.
Non Heap Memory used 34.32 MB of 35.44 MB Commited Non Heap Memory. Max Non Heap Memory is 130 MB.
DFS Used:	209.48 MB
Non DFS Used:	31.35 GB
DFS Remaining:	25.07 GB
DFS Remaining%:	44.27%
Live Nodes	1 (Decommissioned: 0)
Dead Nodes	0 (Decommissioned: 0)
```

* `Safemode is off` is actually what you want to see; if `Safemode is on`, then you do not have enough datanodes.
* 'Live Nodes' should match the number of worker nodes, and Dead Nodes should be zero.
* 'DFS Remaining' should be a healthy number of GB, and
* 'DFS Used', and the number of files and directories, should match the quantity of data you've placed on the HDFS.

* `rake info` should show the `hadoop_nn` container in the running state

* SSH'ing to the machine on port 9422 should give you a shell prompt.

* When you SSH to the machine, running `ps auxf` should show the following:

  ```
  USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
  root         1  0.0  0.1  28820  8488 ?        Ss   05:07   0:00 /usr/bin/python3 -u /sbin/my_init
  root      1943  0.0  0.0    192    36 ?        S    05:07   0:00 /usr/bin/runsvdir -P /etc/service
  root      1944  0.0  0.0    172     4 ?        Ss   05:07   0:00  \_ runsv hadoop_nn
  root      1946  0.0  0.0    188     4 ?        S    05:07   0:00  |   \_ svlogd -tt /bulk/hadoop/log/namenode-daemon
  hdfs      1948  7.3  3.8 1602656 233380 ?      Sl   05:07   0:12  |   \_ /usr/lib/jvm/java-7-oracle/bin/java -Dproc_namenode ...
  root      1945  0.0  0.0    172     4 ?        Ss   05:07   0:00  \_ runsv sshd
  root      1947  0.0  0.0  61368  5328 ?        S    05:07   0:00      \_ /usr/sbin/sshd -D
  root      2033  0.5  0.0  63928  5540 ?        Ss   05:09   0:00          \_ sshd: chimpy [priv] 
  chimpy    2035  0.0  0.0  63928  2888 ?        S    05:09   0:00              \_ sshd: chimpy@pts/0  
  chimpy    2036  0.0  0.0  21312  3740 pts/0    Ss   05:09   0:00                  \_ -bash
  chimpy    2051  0.0  0.0  18688  2612 pts/0    R+   05:09   0:00                      \_ ps axuf
  ```

* The START time of the java process should be about the same as the my_init process. If not, something made the script crash.

* Scan the logs: `tail -F -n 400 /bulk/hadoop/log/namenode-daemon/current`. Scan forward from the
  most recent line reading "`Namenode runit script invoked at ...`". You should see no Java backtraces
  and no messages at `ERROR` status

* If those pages don't open, try accessing them from the docker host:
  - Visit the docker host machine (`boot2docker ssh` or whatever)
  - `curl http://$(hostname):50070/dfshealth.html`
  The curl command should dump a whole bunch of HTML to the screen.


If SSH or web access works from the docker machine but not from its host machine, port forwarding is probably not set up correctly.

### Is the Resource Manager working?

* http://$DOCKER_IP:8088/cluster/nodes should show at least one datanode and no unhealthy datanodes.

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

### Halp my docker disk is full


The combined size of all the compute images (`baseimage`, `hadoop_base`, `hadoop_nn`, `hadoop_snn`, `hadoop_rm`, `hadoop_worker`, `hadoop_lounge`) is a bit under 3GB -- all of the latter are built from hadoop_base, and so re-use the common footprint of data.

The data volumes take up about 1-2GB more. These are representative sizes:

```
Filesystem                Size      Used Available Use% Mounted on
rootfs                    5.2G    204.6M      5.0G   4% /
...
/dev/sda1                26.6G      4.0G     19.7G  15% /mnt/sda1/var/lib/docker/aufs
```

The `rake docker:rmi_blank` command will remove all images that are not part of any tagged image. If you are building and rebuilding containers, the number of intermediate layers from discarded early versions can start to grow; `rake docker:rmi_blank` removes those, leaving all the named layers you actually use.

If you have cleared out all the untagged images, and checked that logs and other foolishness isn't the problem, you might be falling afoul of a bug in current versions of docker (1.3.0). It leads to [large numbers of dangling volumes](https://github.com/docker/docker/issues/6354) -- github/docker [issue #6534](https://github.com/docker/docker/issues/6354) has workarounds.
