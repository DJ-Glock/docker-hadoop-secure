#!/bin/bash

echo "Starting bootstrap.sh"

# FIXME: Need to implement working healthcheck for Kerberos container.
echo "Sleeping 5 seconds"
sleep 5

echo "Preparing Kerberos config"
sudo sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" /etc/krb5.conf
sudo sed -i "s/example.com/${DOMAIN_REALM}/g" /etc/krb5.conf

echo "Updating Hadoop config files"
sudo sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/core-site.xml
sudo sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/core-site.xml
sudo sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/core-site.xml

sudo sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
sudo sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
sudo sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml

sudo sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/yarn-site.xml
sudo sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/yarn-site.xml
sudo sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

sudo sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/mapred-site.xml
sudo sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/mapred-site.xml
sudo sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/mapred-site.xml

sudo sed -i "s#/usr/local/hadoop/bin/container-executor#${NM_CONTAINER_EXECUTOR_PATH}#g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

sudo sed -i "s/localhost/${FQDN}/g" $HADOOP_HOME/etc/hadoop/workers

echo "Updating Spark config"
sudo echo "spark.master  yarn" >> $SPARK_HOME/conf/spark-defaults.conf

echo "Generating kerberos keys"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -pw ${KERBEROS_ROOT_USER_PASSWORD} root@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey dn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey HTTP/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey jhs/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey yarn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey rm/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nm/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey hadoop/$(hostname -f)@${KRB_REALM}"

echo "Exporting keytabs"
sudo mkdir -p $KEYTAB_DIR
sudo chown hadoop:hadoop $KEYTAB_DIR 
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/nn.service.keytab nn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/dn.service.keytab dn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/spnego.service.keytab HTTP/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/jhs.service.keytab jhs/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/yarn.service.keytab yarn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/rm.service.keytab rm/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/nm.service.keytab nm/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k ${KEYTAB_DIR}/hadoop.service.keytab hadoop/$(hostname -f)"

echo "Change permissions of keytabs in ${KEYTAB_DIR}"
sudo chmod 400 ${KEYTAB_DIR}/*.keytab

echo "Starting Open SSH server in background"
sudo /usr/sbin/sshd -D &

echo "Formatting Hadoop data node"
kinit nn/$(hostname -f)@${KRB_REALM} -k -t ${KEYTAB_DIR}/nn.service.keytab
$HADOOP_HOME/etc/hadoop/hadoop-env.sh
hdfs namenode -format

echo "Starting Hadoop daemons"
echo "Starting Namenode"
hdfs --config $HADOOP_CONF_DIR --daemon start namenode

echo "Starting Datanode"
hdfs --config $HADOOP_CONF_DIR --daemon start datanode

echo "Starting Resource Manager"
yarn --config $HADOOP_CONF_DIR --daemon start resourcemanager

echo "Starting History Server"
yarn --config $HADOOP_CONF_DIR --daemon start historyserver

echo "Starting Node Manager"
yarn --config $HADOOP_CONF_DIR --daemon start nodemanager

echo "Setting up permissions for spark"
hdfs dfs -chown hadoop:hadoop /

echo "Hadoop cluster started. Starting endless loop"
while true; do sleep 1000; done
