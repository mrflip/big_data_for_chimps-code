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

```
boot2docker ssh
mkdir -p /tmp/deb_proxy /tmp/bulk/hadoop
touch		    /var/lib/docker/hosts
chmod 0644	    /var/lib/docker/hosts
chown nobody:nobody /var/lib/docker/hosts
```

### Start the helper cluster

```
rake docker:helpers
```

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

