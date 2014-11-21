I have just gotten Lipstick to work on a regular CDH5.2 cluster running in Docker, and I'll send in some pull requests shortly. It is really freaking cool, and was ultimately worth it -- but it took more than a day to figure out and that was only with @thedatachef 's help.

Here is a list of problems that I hit. Most of these will carry little benefit to Netflix but will be significant obstacles for any external adoption. Apart from items 9 and 3, I'm either not equipped to address them or they would impact deployment (eg. item 5). So I'm putting them in as a combined issue rather than stack the tracker with WONTFIXes. If you would please indicate by number which ones deserve to be actual independent issues (i.e. that the project maintainers might put in fixes for), I will file those as separate issues and close this one.

In decreasing order of importance (1 = most valuable to fix):

1. **Lipstick should build against a modern version of Hadoop and Pig**, targeting Hadoop 2.0 branch by default.
   - Even on the Pig 0.13 branch, I could not get it to run against a CDH5 cluster. I even rebuilt the cluster into MRv1 mode -- i.e. Hadoop 2.0 branch but with MRv1 compatibility -- and it still failed.
   - The solution that ultimately worked was to checkout Pig from git branch-0.13, build it against my Hadoop, mavenize that jar, check out lipstick's pig0.13 branch and alter the build scripts to source that custom jar, build the console, then siwtch to master branch and build the server. I'll write this up, but you can see that it's a bumpy road.
   - It's your call whether to target MRv1 or MRv2 by default -- I'd choose the latter -- but the public face should sit atop Hadoop 2.0
   - You don't need to fix the present madness, but you must describe a non-mysterious way to get it running.

2. **Backport the changes on master to the pig0.13 branches**.
  - The pig0.13 branch (i.e. the one any external person would want to use) does not build the modern version of the lipstick-server. Having to build server on one and console on the other is unworkable.
  - Make the master branch be one that builds against a modern Hadoop and presents the version you want people adopting, and move the Netflix-specific version to a separate branch. 

3. **Provide a run script that works against a modern version of Hadoop in non-local mode**.
  - I have a kidnaped version of the Pig 0.13 script that I will make into a pull request.

4. **The properties file should be be `/etc/lipstick/lipstick.properties`, not `/etc/lipstick.properties`.**
  - There are a suprising number of ways in which having files running around naked in the /etc/ directory makes life harder for an ops team (because clutter; because I can't isolate the `lipstick.properties` from a template (`lipstick.properties.mustache`) or alternate version (`lipstick-prod.properties`) in a way that makes it immediately obvious both exist and are related; because I can't cross-mount a directory holding just those files;  because there will certainly come a time when you find the project needs at least one other file).
  - This isn't a major deal, but it is a mistake and it will only get harder to fix in the future.

5. **The lipstick-console sender should read the `lipstick.properties` file**. It's surprising behavior that it doesn't.

6. **Lipstick should build a server jar that just runs v2, as well as a jar that runs both** (I assume you want the jar running both while you migrate internally)
  - Having the legacy version and the current version co-exist is very surprising behavior; and it's difficult to know which is which and whether it matters.
  - If it continues to be a single server, the indicator in the top right should have text saying eg "running V2" and the button read `[switch to V1]`. The current situation doesn't look like a button, and does look like a _label that you are on V2_ rather than _a button that will switch to V2_.

7. **Rename 'console' to 'sender', and 'server' to 'ui'**
  - For a user of the system, a console is a page that I look at to see information, and a server is something that serves data to other robots. Currently, those terms are exactly reversed in meaning, as they would be to the authors of the system.

8. **The names and purposes of the four different jars (-full -withHadoop etc) are very confusing**. The default build of Lipstick should produce only the jars that you need to get started with Lipstick.
  - The pig jar that I run when targeting Hadoop is called `pig-withouthadoop`, which I believe means `pig-without-hadoop-jars-bundled-in-because-your-system-has-them`. The jar that works for me to run pig jobs on a hadoop cluster with Lipstick is `lipstick-withHadoop`. This is highly confusing. Also, the capital letter is a gratuitous trip-up.
  - The error messages when you choose incorrectly are utterly opaque.
  - If one of the jars is for running in local mode, and another is for running against a cluster in mapred mode, I would call them lipstick-local and lipstick-mapred. (That's my best guess as to what some two of the four are for).

9. Some docfixes:
  - clarify that it **requires Java 7+** (because elasticsearch does)
  - clarify that **only the UI server needs access to elasticsearch**.
  - clarify or fix that **only the UI server reads properties** from the `/etc/lipstick.properties` file.
  - clarify that **there is an old version and a new version** and that the project is transitioning.
  - clarify that you **do not need to install groovy or gradle**. Man I spent a lot of time getting those to work only to find out that lipstick (a) wanted version 1.5 of gradle, not any modern version, and (b) didn't need me to do that at all.
  - cleanly and obviously **separate the v1 documentation from the v2 documentation**
  - better **describe what the UI server and console sender do**.
  - **remove all references to Tomcat** into a separate document describing production deployment.


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


