
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
git commit -m "gitignore that which should be ignored" .

echo -e "\n♫ gradle gradle gradle I made you out of clay ♪\n"

false
perl -pi -e 's/# org.apache.pig:pig:0.13.0-h2/# org.apache.pig:pig:0.13.0-h2


./gradlew :lipstick-console:allJars

echo -e "\n♪ And when we are done gradling with lipstick I shall play ♬\n"

mkdir -p /home/chimpy/libs

for flavor in -full.jar .jar -withHadoop.jar -withPig.jar ; do
  ln -snf $LIPSTICK_CONSOLE_LIBS/lipstick-console-$LIPSTICK_VERSION${flavor}.jar \
               /home/chimpy/libs/lipstick-console-${flavor}
done

chown -R 2000:2000 /home/chimpy/libs
