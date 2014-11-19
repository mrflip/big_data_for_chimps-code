

Docker image builder for https://github.com/Netflix/Lipstick/[Lipstick]: "Lipstick combines a graphical depiction of a Pig workflow with information about the job as it executes."

![Lipstick UI](https://raw.github.com/wiki/Netflix/Lipstick/screenshot.png)


```
docker pull dockerfile/elasticsearch
docker run -d --name es dockerfile/elasticsearch
```

```
docker pull debian
git clone (this repo)
cd (the directory with this dockerfile)
docker build -t lipstick .
docker run -it --link=es:es --name lips bd4c/lipstick
```

If you hit problems:

```
docker run -it --link=es:es --publish=9292:9292 --name=lips_debug --entrypoint=/bin/bash lipstick
```


### Notes for Jacob

Lipstick has three components:

* a console, for viewing the beautiful output
* elasticsearch, for collecting the data

It will work with pig in local mode, but you will not get any job statistics. For that, you will need to run

* a lipstick-server running in Tomcat, for gathering data from Hadoop jobs
* a jar that you include when you run your jobs, so that they dispatch metrics to the lipstick as well.

* Java 7, because elasticsearch

* clarify that you do not need to install groovy or gradle
* is the war still a thing?
* How should I run the app for real if not through run-app

* example does not use the UFO dataset.


