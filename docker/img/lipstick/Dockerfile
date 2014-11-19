# FROM library/tomcat:7-jre7
FROM java:7-jdk
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

EXPOSE 9292
USER root

ENV  safe_apt_install apt-get install -y --no-install-recommends
ENV  LIPSTICK_DIR           /usr/local/lipstick
ENV  LIPSTICK_CONSOLE_LIBS  $LIPSTICK_DIR/lipstick-console/build/libs
ENV  JAVA_HOME              /usr/lib/jvm/java-7-openjdk-amd64/jre

RUN \
  apt-get update && \
  $safe_apt_install graphviz nano procps locate git

#
# Get code
#

# Clone repo intoo `-dev`, link it to the canonical named location,
# get the pig0.13 branch we'll use for 
RUN \
  git clone https://github.com/Netflix/Lipstick.git $LIPSTICK_DIR-dev && \
  ln -s $LIPSTICK_DIR-dev $LIPSTICK_DIR                               && \
  git config --global user.email "you@example.com" && git config --global user.name "BD4C Script Robot"

WORKDIR    $LIPSTICK_DIR

RUN \
  echo -e "\n♫ gradle gradle gradle I made you out of clay ♪\n" && \
  env | egrep 'JAVA|LIPSTICK'                                   && \
  git checkout --track -b pig0.13 origin/pig0.13                && \
  echo -e "lipstick-server/config\nlipstick-server/examples\n*.war\n.yardoc\n.gem\nlipstick-server/lib/*.jar\nlipstick-server/app/public/doc" >> .gitignore &&  \
  git commit -m "build changes" .                               && \
  ./gradlew :lipstick-console:allJars

# perl -pi -e 's/2\.3\.0/2.5.0/g' build.gradle                  && \
  
RUN \
  git checkout master && \
  ./gradlew :lipstick-server:war

RUN \
  grep "task('run-app'" $LIPSTICK_DIR/build.gradle    && \
  perl -pi -e "s/task\\(.run-app..*/task\\(\'run-app\', type:JavaExec\\) \\{/" $LIPSTICK_DIR/build.gradle  &&  \
  grep "task('run-app'" $LIPSTICK_DIR/build.gradle    && \
  git commit -m "Don't rebuild universe to run app" .


# RUN \
#   echo -e "\n♪ And when we are done gradling with lipstick I shall play ♬\n"           && \
#   ls -l $LIPSTICK_CONSOLE_LIBS                                                         && \
#   test -f $LIPSTICK_CONSOLE_LIBS/lipstick-console-$LIPSTICK_VERSION.jar                && \
#   ( set -e ; cd $LIPSTICK_CONSOLE_LIBS/                                                && \
#     for flavor in -full.jar .jar -withHadoop.jar -withPig.jar                          ; \
#     do ln -s ./lipstick-console-${LIPSTICK_VERSION}${flavor} ./lipstick-console$flavor ; \
#     done )

COPY      ./conf/lipstick-server.sh  $LIPSTICK_DIR/bin/

ENTRYPOINT ["./bin/lipstick-server.sh"]


# ant -Dhadoopversion=23 clean jar javadoc; mvn org.apache.maven.plugins:maven-install-plugin:2.5:install-file -Dfile=build/pig-0.13.0.jar -DgroupId=org.apache.pig -DartifactId=pig -Dversion=0.13.0 -Dpackaging=jar
