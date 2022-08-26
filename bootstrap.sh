#!/bin/bash

echo "Starting bootstrap.sh"
# FIXME: Need to implement working healthcheck for Kerberos container.
echo "Sleeping 5 seconds"
sleep 5

echo "Preparing Kerberos config"
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" /etc/krb5.conf
sed -i "s/example.com/${DOMAIN_REALM}/g" /etc/krb5.conf

echo "Updating Hadoop config files"
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/core-site.xml
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/core-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/core-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/yarn-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/yarn-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_HOME/etc/hadoop/mapred-site.xml
sed -i "s/HOSTNAME/${FQDN}/g" $HADOOP_HOME/etc/hadoop/mapred-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_HOME/etc/hadoop/mapred-site.xml

sed -i "s#/usr/local/hadoop/bin/container-executor#${NM_CONTAINER_EXECUTOR_PATH}#g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

sed -i "s/localhost/${FQDN}/g" $HADOOP_HOME/etc/hadoop/workers

echo "Updating Spark config"
echo "spark.master  yarn" >> $SPARK_HOME/conf/spark-defaults.conf

echo "Generating kerberos keys"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -pw ${KERBEROS_ROOT_USER_PASSWORD} root@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey dn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey HTTP/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey jhs/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey yarn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey rm/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey nm/$(hostname -f)@${KRB_REALM}"

echo "Exporting keytabs"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k nn.service.keytab nn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k dn.service.keytab dn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k spnego.service.keytab HTTP/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k jhs.service.keytab jhs/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k yarn.service.keytab yarn/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k rm.service.keytab rm/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k nm.service.keytab nm/$(hostname -f)"

echo "Moving keytabs to ${KEYTAB_DIR}"
mkdir -p ${KEYTAB_DIR}
mv nn.service.keytab ${KEYTAB_DIR}
mv dn.service.keytab ${KEYTAB_DIR}
mv spnego.service.keytab ${KEYTAB_DIR}
mv jhs.service.keytab ${KEYTAB_DIR}
mv yarn.service.keytab ${KEYTAB_DIR}
mv rm.service.keytab ${KEYTAB_DIR}
mv nm.service.keytab ${KEYTAB_DIR}
chmod 400 ${KEYTAB_DIR}/nn.service.keytab
chmod 400 ${KEYTAB_DIR}/dn.service.keytab
chmod 400 ${KEYTAB_DIR}/spnego.service.keytab
chmod 400 ${KEYTAB_DIR}/jhs.service.keytab
chmod 400 ${KEYTAB_DIR}/yarn.service.keytab
chmod 400 ${KEYTAB_DIR}/rm.service.keytab
chmod 400 ${KEYTAB_DIR}/nm.service.keytab

echo "Starting Open SSH server in background"
/usr/sbin/sshd -D &

echo "Formatting Hadoop data node"
$HADOOP_HOME/etc/hadoop/hadoop-env.sh
$HADOOP_HOME/bin/hdfs namenode -format

echo "Starting Hadoop"
# For some reason start/stop-dfs.sh scripts do not work.
# $HADOOP_HOME/sbin/start-dfs.sh

hdfs --daemon start namenode
hdfs --daemon start datanode
# kinit nn/hadoop.docker.com@EXAMPLE.COM -k -t /etc/security/keytabs/nn.service.keytab
# hdfs dfs -mkdir /user
# hdfs dfs -mkdir /user/root
# hdfs dfs -ls /user

# echo "Starting YARN"
$HADOOP_HOME/sbin/start-yarn.sh

echo "Starting History Server"
$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver

echo "Hadoop cluster started. Starting endless loop"
while true; do sleep 1000; done
