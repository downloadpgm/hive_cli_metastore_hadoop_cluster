trap "{ echo Stopping play app >/tmp/msg.txt; /usr/bin/bash -c \"/root/stop_spark.sh\"; exit 0; }" SIGTERM

export JAVA_HOME=/usr/local/jre1.8.0_181
export CLASSPATH=$JAVA_HOME/lib
export PATH=$PATH:.:$JAVA_HOME/bin

export HADOOP_HOME=/usr/local/hadoop-2.7.3
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

export HIVE_HOME=/usr/local/apache-hive-1.2.1-bin
export PATH=$PATH:$HIVE_HOME/bin

# create_conf_files.sh

service ssh start

echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
ssh-keyscan ${HOSTNAME} >~/.ssh/known_hosts
