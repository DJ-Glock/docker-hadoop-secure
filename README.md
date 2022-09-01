# Apache Hadoop 3.1.2 Docker image with Kerberos enabled

[![Docker Pulls](https://img.shields.io/docker/pulls/djglock/docker-hadoop-secure.svg)](https://hub.docker.com/r/djglock/docker-hadoop-secure)

This project is a fork from [knappek docker-hadoop-secure](https://github.com/Knappek/docker-hadoop-secure) 
and extends it with Spark. Useful for testing Spark jobs on a Hadoop pseudo cluster.

The Docker image is also available on [Docker Hub](https://hub.docker.com/r/djglock/docker-hadoop-secure).

Versions
--------

* CentOS 7
* Open JDK 8u342-b07 
* Hadoop 3.1.2
* Spark 2.4.7

Default Environment Variables
-----------------------------

| Name | Value | Description |
| ---- | ----  | ---- |
| `KRB_REALM` | `EXAMPLE.COM` | The Kerberos Realm, more information [here](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/krb5_conf.html#) |
| `DOMAIN_REALM` | `example.com` | The Kerberos Domain Realm, more information [here](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/krb5_conf.html#) |
| `KERBEROS_ADMIN` | `admin/admin` | The KDC admin user |
| `KERBEROS_ADMIN_PASSWORD` | `admin` | The KDC admin password |
| `KERBEROS_ROOT_USER_PASSWORD` | `password` | The password of the Kerberos principal `root` which maps to the OS root user |

You can simply define these variables in the `docker-compose.yml`.

Default user for Spark
-----------------------------
Default user:group for spark jobs: hadoop:hadoop.

Run image
---------

Clone the [Github project](https://github.com/DJ-Glock/docker-hadoop-secure) and run

```
docker-compose up -d
```

As an alternative - you can use TestContainers for testing. You will have to use provided docker-compose file or setup the same programmatically.

Usage
-----

Get the container name with `docker ps` and login to the container with

```
docker exec -it <container-name> /bin/bash
```

To obtain a Kerberos ticket, execute

```
kinit <username> -k -t ${KEYTAB_DIR}/keytab.name
```

Afterwards you can use `hdfs` CLI like

```
hdfs dfs -ls /
```

Run spark-submit job that will write or read files into HDFS.

Known issues
------------

### Java Keystore

If the Keystroe has been expired, then create a new `keystore.jks`:

1. create private key

```
openssl genrsa -des3 -out server.key 1024
```

2. create csr

```
openssl req -new -key server.key -out server.csr
```

3. remove passphrase in key
```
cp server.key server.key.org
openssl rsa -in server.key.org -out server.key
```

3. create self-signed cert
```
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
```

4. create JKS and import certificate. Set password: bigdata
```
keytool -import -keystore keystore.jks -alias CARoot -file server.crt
```


## Credits
Some docs
- https://hadoop.apache.org/docs/r3.1.2/hadoop-project-dist/hadoop-common/SingleCluster.html#Pseudo-Distributed_Operation
- https://hadoop.apache.org/docs/r3.1.2/hadoop-project-dist/hadoop-common/ClusterSetup.html
- https://www.linode.com/docs/guides/install-configure-run-spark-on-top-of-hadoop-yarn-cluster/
