# Hive client running into Spark/Hadoop cluster in Docker

Apache Hadoop is an open-source, distributing filesystem across clusters of commodity computers. 

Apache Spark is an open-source, distributed processing system used for big data workloads.

Apache Hive is a distributed, fault-tolerant data warehouse system that enables analytics at a massive scale over Hadoop.

In this demo, Hive client access a metastore in Mysql populated by Spark client container. Whole process is backed by Hadoop distributed filesystem (HDFS) to store the tables.

This Docker image contains Hive binaries prebuilt and uploaded in Docker Hub.

Spark client access a remote Hive metastore created in a MySQL Server for Spark catalog.


## Start Swarm cluster

1. start swarm mode in node1
```shell
$ docker swarm init --advertise-addr <IP node1>
$ docker swarm join-token worker  # issue a token to add a node as worker to swarm
```

2. add 3 more workers in swarm cluster (node2, node3, node4)
```shell
$ docker swarm join --token <token> <IP nodeN>:2377
```

3. label each node to anchor each container in swarm cluster
```shell
docker node update --label-add hostlabel=hdpmst node1
docker node update --label-add hostlabel=hdp1 node2
docker node update --label-add hostlabel=hdp2 node3
docker node update --label-add hostlabel=hdp3 node4
```

4. create an external "overlay" network in swarm to link the 2 stacks (hdp and spk)
```shell
docker network create --driver overlay mynet
```

5. start hive client with hadoop standalone server, spark client and mysql server
```shell
$ docker stack deploy -c docker-compose.yml spk
$ docker service ls
ID             NAME          MODE         REPLICAS   IMAGE                              PORTS
kbdg1lfzcrr6   spk_hdpmst    replicated   1/1        mkenjis/ubhive_img:latest          
l1pdt972ep82   spk_mysql     replicated   1/1        mysql:5.7                          
o5gzr0yowk60   spk_spk_cli   replicated   1/1        mkenjis/ubspkcli_yarn_img:latest
```

## Set up MySQL server

1. download hive binaries and unpack it
```shell
wget https://archive.apache.org/dist/hive/hive-1.2.1/apache-hive-1.2.1-bin.tar.gz
tar -xzf apache-hive-1.2.1-bin.tar.gz
```

2. access mysql server node and run hive script to create metastore tables
```shell
cd /root/staging/apache-hive-1.2.1-bin/scripts/metastore/upgrade/mysql
mysql -uroot -p metastore < hive-schema-1.2.0.mysql.sql
Enter password:
```

## Upload a datafile into HDFS server

1. access hadoop standalone server and load a datafile.
```shell
$ docker container exec -it <hive_cli ID> bash
```

```shell
hdfs dfs -mkdir /data
hdfs dfs -put housing.data /data
hdfs dfs -ls /data
```

## Set up Spark client

1. access spark client node
```shell
$ docker container exec -it <spk_cli ID> bash
```

2. copy following files into $SPARK_HOME/conf
```shell
$ cd $SPARK_HOME/conf
$ scp root@<hdpmst>:/usr/local/hadoop-2.7.3/etc/hadoop/core-site.xml .
$ scp root@<hdpmst>:/usr/local/hadoop-2.7.3/etc/hadoop/hdfs-site.xml .
$ # create hive-site.xml with settings provided
```

3. start spark-shell installing mysql jar files
```shell
$ spark-shell --packages mysql:mysql-connector-java:5.1.49
2021-12-05 11:09:14 WARN  NativeCodeLoader:62 - Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
Setting default log level to "WARN".
To adjust logging level use sc.setLogLevel(newLevel). For SparkR, use setLogLevel(newLevel).
2021-12-05 11:09:40 WARN  Client:66 - Neither spark.yarn.jars nor spark.yarn.archive is set, falling back to uploading libraries under SPARK_HOME.
Spark context Web UI available at http://802636b4d2b4:4040
Spark context available as 'sc' (master = yarn, app id = application_1638723680963_0001).
Spark session available as 'spark'.
Welcome to
      ____              __
     / __/__  ___ _____/ /__
    _\ \/ _ \/ _ `/ __/  '_/
   /___/ .__/\_,_/_/ /_/\_\   version 2.3.2
      /_/
         
Using Scala version 2.11.8 (Java HotSpot(TM) 64-Bit Server VM, Java 1.8.0_181)
Type in expressions to have them evaluated.
Type :help for more information.

scala> 
```

4. create a persistent tables in metastore
```shell
scala> val df = spark.read.option("inferSchema","true").csv("hdfs://hdpmst:9000/data/housing.data").
                toDF("CRIM","ZN","INDUS","CHAS","NOX","RM","AGE","DIS","RAD","TAX","PTRATIO","B","LSTAT","MEDV")
scala> df.show
scala> df.write.saveAsTable("housing")
scala> df.write.format("csv").saveAsTable("housing_csv")
scala> df.write.format("json").saveAsTable("housing_json")
scala> df.write.format("orc").saveAsTable("housing_orc")
scala> 
```

## Set up Hive client

1. access hive client node
```shell
$ docker container exec -it <hive_cli ID> bash
```

2. copy following file into $HIVE_HOME/conf
```shell
$ cd $HIVE_HOME/conf
$ # create hive-site.xml with settings provided. replace hdpmst hostname to physical hostname
```

3. start hive CLI
```shell
$ cd ~
$ hive

Logging initialized using configuration in jar:file:/usr/local/apache-hive-1.2.1-bin/lib/hive-common-1.2.1.jar!/hive-log4j.properties
hive> show tables;
OK
housing
Time taken: 1.217 seconds, Fetched: 1 row(s)
```
