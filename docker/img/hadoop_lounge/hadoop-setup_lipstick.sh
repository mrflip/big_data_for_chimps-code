#!/bin/bash
set -e ; set -v ; date

#
# Lipstick
#

$safe_apt_install graphviz

# Clone repo into a directory with version `dev`, link it to the canonical
# named location
#
git clone https://github.com/Netflix/Lipstick.git $LIPSTICK_DIR-dev
ln -s $LIPSTICK_DIR-dev $LIPSTICK_DIR

env | egrep 'JAVA|LIPSTICK'

# Work with the pig0.13 branch for the consol
cd $LIPSTICK_DIR
git checkout --track -b pig0.13 origin/pig0.13
echo -e "lipstick-server/config\nlipstick-server/examples\n*.war\n.yardoc\n.gem\nlipstick-server/lib/*.jar\nlipstick-server/app/public/doc" >> .gitignore
git config --global user.email "you@example.com" && git config --global user.name "BD4C Script Robot"
perl -pi -e 's/(hadoop-.*):2\.3\.0/\1:2.5.0/g' build.gradle 
perl -pi -e 's/(:pig.*):0\.13\.0/\1:0.13.1-h2/g' build.gradle 
git commit -m "use our pig and our hadoop. and gitignore more" .

echo -e "\n♫ gradle gradle gradle I made you out of clay ♪\n"

./gradlew :lipstick-console:allJars

echo -e "\n♪ And when we are done gradling with lipstick I shall play ♬\n"

# for flavor in -full.jar .jar -withHadoop.jar -withPig.jar ; do
#   ln -snf $LIPSTICK_CONSOLE_LIBS/lipstick-console-$LIPSTICK_VERSION${flavor} \
#                /home/chimpy/libs/lipstick-console${flavor}
# done
