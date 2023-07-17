FROM mkenjis/ubhdp_img

#ARG DEBIAN_FRONTEND=noninteractive
#ENV TZ=US/Central

WORKDIR /usr/local

# wget https://archive.apache.org/dist/hive/hive-1.2.1/apache-hive-1.2.1-bin.tar.gz
ADD apache-hive-1.2.1-bin.tar.gz .

WORKDIR /usr/local/apache-hive-1.2.1-bin
COPY hive-env.sh conf/hive-env.sh
COPY mysql_mysql-connector-java-5.1.49.jar lib/mysql_mysql-connector-java-5.1.49.jar

WORKDIR /root
RUN echo "" >>.bashrc \
 && echo 'export HIVE_HOME=/usr/local/apache-hive-1.2.1-bin' >>.bashrc \
 && echo 'export PATH=$PATH:$HIVE_HOME/bin' >>.bashrc
 
COPY run_hive.sh .

RUN chmod +x run_hive.sh

COPY supervisord_hive.conf /etc/supervisor/conf.d/supervisord_hive.conf
