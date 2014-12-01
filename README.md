# Big Data for Chimps Example Code

The first step is to clone this repo:

```
    $ git clone --recursive http://github.com/mrflip/big_data_for_chimps-code.git bd4c-code
```

_TODO: change the git address when we move the repo_

You will now see a directory called `bd4c-code`.

Everything below (apart from one quick step) should take place in the `bd4c-code/cluster/` directory. **DO NOT USE THE `bd4c-code/docker/` DIRECTORY** -- that is for generating the docker containers, and you will want to use the pre-validated ones to start off.

For the experienced and reckless, there's a compact summary version following the walkthrough; and if you hit a hitch, extensive troubleshooting notes follow. We've frequently experienced the pain of trying to run sample code from a book where minor shifts in the underlying technology have broken the code in some baffling way; and the technology here is still changing quickly and particularly complex. So we've added "progress checks" throughout this document and the notes/Troubleshooting.md document: ways to firewall a problem with one piece (eg. getting hostnames distributed to each node) from problems in the next piece (eg. provisioning the pre-assembled volumes). That way, when bitrot does eventually happen -- or if you have a setup that provides the capability some other way -- you only have to ensure that progress checks are satisfied.

* /README.md -- walkthrough and summary
* /notes/Troubleshooting.md -- detailed checks on each component

## Quickstart for the experienced and reckless


Here's the TL;DR summary. Clone the repo and install the dependencies.

```
git clone --recursive http://github.com/mrflip/big_data_for_chimps-code.git bd4c-code
cd bd4c-code
gem install bundler
bundle install
```

If you're running boot2docker, you'll want to forward the virtual machine's ports to your host system.

```
boot2docker down
rake docker:open_ports
$(boot2docker up 2>&1 | egrep '^ *export')
```

Start your docker server, and validate that everything is a-OK:

```
env | grep DOCKER  # should show a valid DOCKER_HOST, etc.
docker info        # should have no errors or obvious defects
rake info          # ditto
``` 

Pull in the images, then go read 'Big Data for Chimps' for 10-40 minutes as 6GB of data rolls in:

```
rake images:pull
```

Bring the cluster up:

```
rake ready
rake up
```

Now you can log on to the `hadoop_lounge` machine.

```
ssh -i insecure_key.pem chimpy@DOCKER_ADDR:9022 
```

Replace `DOCKER_ADDR` with the Docker Host IP address from `rake info`, or as given to you when you installed docker.

And you can view the Hue console at http://DOCKER_ADDR:10000/


## Cluster Setup Part I: Preliminaries

### Prerequisites

* Basic comfort pasting things into a terminal window and hitting enter.
* Ruby interpreter
* A Docker server -- we recommend Boot2Docker, if you're on OSX or Windows

### Ruby and Required Libraries

These scripts require a reasonably modern version of ruby (> 2.0 preferred, but certainly >= 1.9.2). Open a terminal window and run the following at the command line:

        bd4c-code/cluster$ ruby --version
    ruby 2.1.4p265 (2014-10-27 revision 48166) [x86_64-darwin13.0]

_(We'll indent command lines by four spaces in these listings so you can identify the input from output. Your job is to be in the directory to the left of the $ and run the command to the right of the $.)_

If you don't like what you see, follow the instructions at [the official Ruby website](https://www.ruby-lang.org/en/installation/). The Ruby that is pre-installed with all recent versions of OSX should work fine, and so will any of the other ways they recommend. Linux users should use [the appropriate package manager](https://www.ruby-lang.org/en/installation/), and Windows users reportedly have best success with [RubyInstaller](https://www.ruby-lang.org/en/installation/#rubyinstaller).

Next, install the required libraries:

        bd4c-code/cluster$ gem install bundler
    Fetching: bundler-1.7.7.gem (100%)
    Successfully installed bundler-1.7.7
    1 gem installed

        bd4c-code/cluster$ bundle install
    Using rake 10.3.2
      ...(snip)...
    Using bundler 1.7.7
    Your bundle is complete!
    Use `bundle show [gemname]` to see where a bundled gem is installed.


### Running under boot2docker

#### Port Forwarding

By forwarding selected ports from the Boot2Docker VM to the OSX host, you'll be able to ssh directly to the machines from your regular terminal window, and will be able to directly browse the various web interfaces. It's highly recommended, but you need to pause the boot2docker VM for a moment to accomplish this. Let's do that now before we dive in.

```
    bd4c-code/cluster$ boot2docker down
    bd4c-code/cluster$ rake docker:open_ports
```

#### Increase size of the Boot2Docker VM

While you have the VM down, you should also increase the amount of memory you're allocating to the VM.

* Open the VirtualBox manager (the standalone program that looks like a cube, not a VM)
* Select the virtual machine, probably called  `boot2docker-vm`.
* Hit 'Settings'.
  - Under the System tab, you will see the base memory slider
  - adjust that to at least 4GB, 6-8GB if you can spare it. Don't go higher than 50% of the physical ram on your machine, though.

Please also note that the size of boot2docker's virtual hard drive is 20GB by default. We'll be taking up about 6GB of it from the start for the data and machine images, and of course you will then use it to generate lovely output data. As long as we don't have to share with any other heavy users, though, the 20GB is quite enough space, and resizing the boot2docker volume is a giant pain. So cross that bridge if you meet it. If you find that your drive is full but you haven't generated anything like 14GB of additional data, see the troubleshooting document -- it's possibly a flaw in current docker.

### Environment Variables: `DOCKER_HOST` and friends

The `docker` command and our runner scripts use a set of environment variables -- `DOCKER_HOST`, plus `DOCKER_CERT_PATH` and `DOCKER_TLS_VERIFY` if secure-connections are enabled -- to discover the docker server.

#### For boot2docker users:

Starting boot2docker as follows will start the vm and set the magic environment variables in one go:

```
$(boot2docker up 2>&1 | egrep '^ *export')
boot2docker up
```

The first command is actually all you need, but we kidnap its output to set the environment variables, so we run the second line to affirm that it worked. In action:


        bd4c-code/cluster$ $(boot2docker up 2>&1 | egrep '^ *export')
        bd4c-code/cluster$ boot2docker up
    Waiting for VM and Docker daemon to start...
    .o
    Started.
    Writing /Users/flip/.boot2docker/certs/boot2docker-vm/ca.pem
    Writing /Users/flip/.boot2docker/certs/boot2docker-vm/cert.pem
    Writing /Users/flip/.boot2docker/certs/boot2docker-vm/key.pem
    Your environment variables are already set correctly.


#### For others

Users of a non-local docker server should set those three variables in their `.bashrc` file. (boot2docker users can too, as the hostname usually stays constant from run to run -- but it's all according to VirtualBox's whim and I find the port changes from time to time). Using the current values on my machine, I have these lines in my `.bashrc`:

```
export DOCKER_ADDR=192.168.59.103
export DOCKER_HOST=tcp://$DOCKER_ADDR:2375
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=$HOME/.boot2docker/certs/boot2docker-vm
```

#### Check that Docker is ready to go

You can check the environment variables as follows. Note the IP address in DOCKER_HOST (i.e. without the `tcp://` or `2375`) -- we'll refer to it with the shorthand `DOCKER_ADDR` when we need it.

        bd4c-code/cluster$ env | grep DOCKER
    DOCKER_HOST=tcp://192.168.59.103:2375
    DOCKER_TLS_VERIFY=1
    DOCKER_CERT_PATH=/Users/flip/.boot2docker/certs/boot2docker-vm

(Only set `DOCKER_TLS_VERIFY=1` if your docker does indeed use secure connections. If you see the unhelpful error message `malformed HTTP response "\x15\x03\x01\x00\x02\x02"`, your docker expects TLS and you're not supplying it.)

Run the `docker info` command. Your details may vary from the partial output shown; the important thing is that it completes without error.

        bd4c-code/cluster$ bundle install
    Containers: 0
    Images: 0
    EventsListeners: 0
    Init Path: /usr/local/bin/docker
      ...snip..
    Registry: [https://index.docker.io/v1/]


        bd4c-code/cluster$ rake docker:info
    Global info for tcp://192.168.59.103:2376
    Containers:     0
    Images:         458
    Registry:       https://index.docker.io/v1/
    Root Volume:    /mnt/sda1/var/lib/docker/aufs
    PortForwarding: true
    Docker Version: {"ApiVersion"=>"1.15", "Arch"=>"amd64", "GoVersion"=>"go1.3.3", ...}

If your ruby environment is good, the last command's output will be similar to that of `docker info`. _(Ours highlights only the essential info and uses more-familiar terms. It's also tab-delimited, allowing cut and sort to work. Again, all you care about is that there are no errors or flaming defects in what you see.)_

### Pull in the containers

Our tools are in place, now we need the raw materials.

The following will pre-seed the containers we'll use. This is going to bring in more than 4 GB of data, so don't do this at a coffee shop, and do be patient.

```
rake images:pull
```

You can do the next step while that proceeds.

### Wait until the pull completes

Don't proceed past this point until the `rake images:pull` has succeeded. Time for some rolly-chair swordfighting!

## Dockering II: Start it Up!

### Preliminaries Complete!

You're ready to proceed when:

* Running `echo $DOCKER_HOST` from your terminal returns the address of your docker host
* Running `rake ps` succeeds and shows no containers in existence.
* Running `rake images:pull` marches through the list fairly quickly, reporting in a bored tone that it already has everything.
* For boot2docker users, `ls -l /var/lib/docker/hosts` on the docker host shows a file of zero size. (That, or `cat /var/lib/docker/hosts` shows a healthy-looking hosts file, in case you're unwinding back to this point from further on.)

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

The friendly Hue console will be available at http://DOCKER_ADDR:9001/ in your browser (substitute the ip address of your docker). The login and password are 'chimpy' and 'chimpy'. Ignore any whining it does about Oozie or Pig not working -- those are just front-end components we haven't installed.

* Visit the File Browser and drill down to http://DOCKER_ADDR:9001/filebrowser/#/data/gold  You'll see all the different datasets we'll use. There's lots of fun stuff in there -- finishing the book will leave you ready to design your own investigations, and so we've provided lots of territory to explore.
* Visit the Job Browser. Nothing going on yet, of course, but you'll be back here in a moment.

#### SSH terminal access

You will also spend some time commanding a terminal directly on the machine. Even if you're not one of the many people who prefer the commandline way, in the later chapters you'll want to peek under the covers of what's going on within each of the machines. SSH across by running

```
ssh -i insecure_key.pem chimpy@DOCKER_ADDR -p 9022
```

All of the nodes in the cluster are available for ssh. Using the normal SSH port of 22 as a mnemonic, we've set each container up in ascending centuries:

* Lounge:         9022
* Worker:         9122
* Resource Manager:   9322 (manages but does not run jobs -- the new-school jobtracker)
* Namenode:       9422 (manages but does not hold data)
* Secondary Namenode: 9522 (keeps the namenode healthy. Does *not* act as a failover namenode)

9222 is reserved for a second worker, if you have the capacity.

#### The dangerous thing we did that you need to know about

We've done something here that usually violates taste, reason and safety: the private key that controls access to the container is available to anyone with a browse. To bring that point home, the key is named `insecure_key.pem`. Our justification is that these machines are (a) designed to work within the private confines of a VM, without direct inbound access from the internet, and (b) are low-stakes playgrounds with only publicly redistributable code and data sets. If either of those assumptions becomes untrue -- you are pushing to the docker cloud, or using these machines to work with data of your own, or whatever -- then we urge you to construct new private/public keypairs specific _only_ to each machine, replacing the `/root/.ssh/authorized_keys` and `/home/chimpy/.ssh/authorized_keys` files. (It's those latter files that grant access; the existing key must be removed and a new one added to retain access.) It's essential that any private keys you generate be unique to these machines: it's too easy to ship a container to the wrong place or with the wrong visibility at the current maturity of these tools. So don't push in the same key you use for accessing work servers or github or docker or the control network for your secret offshore commando HQ.

### I WANT TO SEE DATA GO, YOU PROMISED

Right you are. There's tons of examples in the book, of course, but let's make some data fly now and worry about the details later.

#### See pig in action

On hadoop:

```
cd book/code/
  # This file isn't on the HDFS right now, so put it there:
hadoop fs -mkdir -p /data/gold/geo/ufo_sightings
hadoop fs -put      /data/gold/geo/ufo_sightings/ufo_sightings.tsv.bz2 /data/gold/geo/ufo_sightings/ufo_sightings.tsv.bz2
  # Run, pig, run!
hadoop fs -rm -r -f /data/outd/ufos/sightings_hist
cd ~/book/code ; . /etc/default/hadoop ; pig -x mapred 04-intro_to_pig/a-ufo_visits_by_month.pig
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
