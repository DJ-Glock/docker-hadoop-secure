FROM --platform=linux/amd64 centos:7

USER root

### Prerequisites
RUN yum install -y less wget curl which tar sudo openssh-server openssh-clients rsync net-tools

RUN wget https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u342-b07/openlogic-openjdk-8u342-b07-linux-x64.tar.gz &&\
    mkdir -p /usr/java/default && \
    mkdir -p /tmp/java && \
    tar -zxvf openlogic-openjdk-8u342-b07-linux-x64.tar.gz -C /tmp/java && \
    rm openlogic-openjdk-8u342-b07-linux-x64.tar.gz && \
    mv /tmp/java/openlogic-openjdk-8u342-b07-linux-x64/* /usr/java/default
ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin

### Kerberos
RUN yum install -y krb5-libs krb5-workstation krb5-auth-dialog && \
    mkdir -p /var/log/kerberos && \
    touch /var/log/kerberos/kadmind.log
ADD config_files/krb5.conf /etc/krb5.conf

### Hadoop
RUN wget https://archive.apache.org/dist/hadoop/core/hadoop-3.1.2/hadoop-3.1.2.tar.gz && \
    mkdir -p /tmp/hadoop && \
    mkdir /usr/local/hadoop && \
    tar -zxvf hadoop-3.1.2.tar.gz -C /tmp/hadoop && \
    rm hadoop-3.1.2.tar.gz && \
    mv /tmp/hadoop/hadoop-3.1.2/* /usr/local/hadoop

ENV HADOOP_HOME /usr/local/hadoop
ENV PATH $HADOOP_HOME/bin:$PATH

ENV HADOOP_COMMON_HOME $HADOOP_HOME
ENV HADOOP_HDFS_HOME $HADOOP_HOME
ENV HADOOP_MAPRED_HOME $HADOOP_HOME
ENV HADOOP_YARN_HOME $HADOOP_HOME
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop
ENV NM_CONTAINER_EXECUTOR_PATH $HADOOP_HOME/bin/container-executor
ENV HADOOP_BIN_HOME $HADOOP_HOME/bin
ENV PATH $PATH:$HADOOP_BIN_HOME

ENV HDFS_NAMENODE_USER="root"
ENV HDFS_DATANODE_USER="root"
ENV HDFS_SECONDARYNAMENODE_USER="root"
ENV YARN_RESOURCEMANAGER_USER="root"
ENV YARN_NODEMANAGER_USER="root"

RUN mkdir $HADOOP_HOME/input && \
    cp $HADOOP_HOME/etc/hadoop/*.xml $HADOOP_HOME/input

ADD config_files/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN chmod +x $HADOOP_HOME/etc/hadoop/hadoop-env.sh
ADD config_files/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml
ADD config_files/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml
ADD config_files/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml
ADD config_files/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml
ADD config_files/container-executor.cfg $HADOOP_HOME/etc/hadoop/container-executor.cfg
RUN mkdir $HADOOP_HOME/nm-local-dirs \
    && mkdir $HADOOP_HOME/nm-log-dirs 
ADD config_files/ssl-server.xml $HADOOP_HOME/etc/hadoop/ssl-server.xml
ADD config_files/ssl-client.xml $HADOOP_HOME/etc/hadoop/ssl-client.xml
ADD config_files/keystore.jks $HADOOP_HOME/lib/keystore.jks

### Hadoop-Secure
ENV KRB_REALM EXAMPLE.COM
ENV DOMAIN_REALM example.com
ENV KERBEROS_ADMIN admin/admin
ENV KERBEROS_ADMIN_PASSWORD admin
ENV KERBEROS_ROOT_USER_PASSWORD password
ENV KEYTAB_DIR /etc/security/keytabs
ENV FQDN hadoop.com

### SSH for yarn
ADD config_files/ssh_config /root/.ssh/config
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key && \
    ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -q -N "" -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key && \
    ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa && \
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/config && \
    chown root:root /root/.ssh/config

### Spark
RUN wget https://archive.apache.org/dist/spark/spark-2.4.7/spark-2.4.7-bin-hadoop2.7.tgz && \
    mkdir -p /tmp/spark && \
    mkdir -p /usr/local/spark && \
    tar -zxvf spark-2.4.7-bin-hadoop2.7.tgz -C /tmp/spark && \
    mv /tmp/spark/spark-2.4.7-bin-hadoop2.7/* /usr/local/spark &&\
    rm spark-2.4.7-bin-hadoop2.7.tgz
ENV SPARK_HOME /usr/local/spark
ENV PATH $PATH:$SPARK_HOME/bin
ENV LD_LIBRARY_PATH $HADOOP_HOME/lib/native:$LD_LIBRARY_PATH
RUN mv $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf

### Bootstrap script with configs changes and startup
ENV BOOTSTRAP /etc/bootstrap.sh
ADD bootstrap.sh $BOOTSTRAP
RUN chown root:root $BOOTSTRAP && \
    chmod 700 $BOOTSTRAP

CMD ["/etc/bootstrap.sh"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
