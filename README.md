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

## Set up Hive client

1. in hive client node, copy following file into $HIVE_HOME/conf
```shell
$ docker container exec -it <hive_cli ID> bash
```

```shell
$ cd $HIVE_HOME/conf
$ # create hive-site.xml with settings provided. NOTE: replace hdpmst hostname to physical hostname
```

2. create dir at HDFS to store Hive table data
```shell
$ hdfs dfs -mkdir -p /user/hive/warehouse
$ hdfs dfs -mkdir /tmp
```

```shell
$ hdfs dfs -chmod g+w /user/hive/warehouse
$ hdfs dfs -chmod g+w /tmp
```

3. initialize mysql database with Hive metastore
```shell
$ bin/schematool -initSchema -dbType mysql
Metastore connection URL:        jdbc:mysql://mysql:3306/metastore?useSSL=false
Metastore Connection Driver :    com.mysql.jdbc.Driver
Metastore connection User:       hiveuser
Starting metastore schema initialization to 1.2.0
Initialization script hive-schema-1.2.0.mysql.sql
Initialization script completed
schemaTool completed
```

4. start hive CLI
```shell
$ cd ~
$ hive

Logging initialized using configuration in jar:file:/usr/local/apache-hive-1.2.1-bin/lib/hive-common-1.2.1.jar!/hive-log4j.properties
hive> show databases;
OK
default
Time taken: 1.673 seconds, Fetched: 1 row(s)
hive> show tables;
OK
Time taken: 0.091 seconds
hive>
```

5. create a sample table
```shell
hive> create table employee (id string, name string, dept string) row format delimited fields terminated by ',' stored as textfile;
OK
Time taken: 0.43 seconds
hive> insert into employee values ('1','john','hr'),('2','ann','pln'),('3','jeff','wrh'),('4','mary','prd');
Query ID = root_20231001122701_962b8e07-b087-4ebf-848a-5adfd91a6f95
Total jobs = 3
Launching Job 1 out of 3
Number of reduce tasks is set to 0 since there's no reduce operator
Job running in-process (local Hadoop)
2023-10-01 12:27:05,634 Stage-1 map = 100%,  reduce = 0%
Ended Job = job_local335338631_0001
Stage-4 is selected by condition resolver.
Stage-3 is filtered out by condition resolver.
Stage-5 is filtered out by condition resolver.
Moving data to: hdfs://f0428922c1bb:9000/user/hive/warehouse/employee/.hive-staging_hive_2023-10-01_12-27-01_347_6385104716718512762-1/-ext-10000
Loading data to table default.employee
Table default.employee stats: [numFiles=1, numRows=4, totalSize=42, rawDataSize=38]
MapReduce Jobs Launched:
Stage-Stage-1:  HDFS Read: 42 HDFS Write: 156 SUCCESS
Total MapReduce CPU Time Spent: 0 msec
OK
Time taken: 4.932 seconds
hive> show tables;
OK
employee
values__tmp__table__1
Time taken: 0.062 seconds, Fetched: 2 row(s)
hive> select * from employee;
OK
1       john    hr
2       ann     pln
3       jeff    wrh
4       mary    prd
Time taken: 0.173 seconds, Fetched: 4 row(s)
```


## Set up Spark client

1. in spark client node, copy following files into $SPARK_HOME/conf
```shell
$ docker container exec -it <spk_cli ID> bash
```

```shell
$ cd $SPARK_HOME/conf
$ # create hive-site.xml with settings provided. NOTE: replace hdpmst hostname to physical hostname
```

2. start spark-shell installing mysql jar files
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

3. checkout table created using hive
```shell
scala> spark.sql("show databases").show
2023-10-01 12:33:14 WARN  ObjectStore:568 - Failed to get database global_temp, returning NoSuchObjectException
+------------+
|databaseName|
+------------+
|     default|
+------------+

scala> spark.sql("show tables").show
+--------+---------+-----------+
|database|tableName|isTemporary|
+--------+---------+-----------+
| default| employee|      false|
+--------+---------+-----------+

scala> val df = spark.sql("select * from employee")
df: org.apache.spark.sql.DataFrame = [id: string, name: string ... 1 more field]

scala> df.printSchema
root
 |-- id: string (nullable = true)
 |-- name: string (nullable = true)
 |-- dept: string (nullable = true)

scala> df.show
+---+----+----+
| id|name|dept|
+---+----+----+
|  1|john|  hr|
|  2| ann| pln|
|  3|jeff| wrh|
|  4|mary| prd|
+---+----+----+
```