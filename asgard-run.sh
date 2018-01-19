#!/bin/bash

# VARIAVEIS COMUNS A TODOS OS PROCESSOS
NETWORK_NAME="asgard"
ZK_1_IP=172.18.0.2
ZK_2_IP=172.18.0.3
ZK_3_IP=172.18.0.4
ZK_CLUSTER_IPS=${ZK_1_IP}:2181,${ZK_2_IP}:2181,${ZK_3_IP}:2181

MESOS_MASTER_IP=172.18.0.11
MESOS_SLAVE_IP=172.18.0.21
MARATHON_IP=172.18.0.31

docker network create --subnet 172.18.0.0/16 asgard

# ZK Cluster

ZOO_SERVERS="server.1=${ZK_1_IP}:2888:3888 server.2=${ZK_2_IP}:2888:3888 server.3=${ZK_3_IP}:2888:3888"
ZOO_PURGE_INTERVAL=10
echo -n "ZK (${ZK_1_IP}) "
docker run -d \
  --name asgard_zk_1 \
  --rm -it --ip ${ZK_1_IP} \
  -e ZOO_MY_ID=1 \
  --net ${NETWORK_NAME} \
  --env-file <(
echo ZOO_SERVERS=${ZOO_SERVERS}
echo ZOO_PURGE_INTERVAL=${ZOO_PURGE_INTERVAL}
) docker.sieve.com.br/infra/zookeeper:0.0.1

echo -n "ZK (${ZK_2_IP}) "
docker run -d --rm -it --ip ${ZK_2_IP} \
  --name asgard_zk_2 \
  -e ZOO_MY_ID=2 \
  --net ${NETWORK_NAME} \
  --env-file <(
echo ZOO_SERVERS=${ZOO_SERVERS}
echo ZOO_PURGE_INTERVAL=${ZOO_PURGE_INTERVAL}
) docker.sieve.com.br/infra/zookeeper:0.0.1

echo -n "ZK (${ZK_3_IP}) "
docker run -d --rm -it --ip ${ZK_3_IP} \
  --name asgard_zk_3 \
  -e ZOO_MY_ID=3 \
  --net ${NETWORK_NAME} \
  --env-file <(
echo ZOO_SERVERS=${ZOO_SERVERS}
echo ZOO_PURGE_INTERVAL=${ZOO_PURGE_INTERVAL}
) docker.sieve.com.br/infra/zookeeper:0.0.1


## MESOS


MESOS_QUORUM=1
MESOS_IP=${MESOS_MASTER_IP}
MESOS_WORK_DIR=/var/lib/mesos
MESOS_HOSTNAME_LOOKUP=false
MESOS_ZK=zk://${ZK_CLUSTER_IPS}/mesos
#  volumes:
#    - /var/lib/mesos/:/var/lib/mesos/:rw

echo -n "Mesos Master (${MESOS_MASTER_IP}) "
docker run -d --rm -it --ip ${MESOS_MASTER_IP} \
  --name asgard_mesosmaster \
  --net ${NETWORK_NAME} \
  --env-file <(
echo MESOS_QUORUM=${MESOS_QUORUM}
echo MESOS_IP=${MESOS_IP}
echo MESOS_WORK_DIR=${MESOS_WORK_DIR}
echo MESOS_HOSTNAME_LOOKUP=${MESOS_HOSTNAME_LOOKUP}
echo MESOS_ZK=${MESOS_ZK}
) docker.sieve.com.br/centos7/mesos:0.0.3 /usr/sbin/mesos-master


## MESOS SLAVE
MESOS_IP=${MESOS_SLAVE_IP}
LIBPROCESS_ADVERTISE_IP=${MESOS_SLAVE_IP}
MESOS_ATTRIBUTES=";owner:sieve;mesos:slave;workload:general"
MESOS_MASTER=zk://${ZK_CLUSTER_IPS}/mesos
MESOS_EXECUTOR_REGISTRATION_TIMEOUT=5mins
MESOS_CONTAINERIZERS=docker
MESOS_HOSTNAME_LOOKUP=false
MESOS_GC_DELAY=60mins
MESOS_SWITCH_USER=false
MESOS_SYSTEMD_ENABLE_SUPPORT=false
MESOS_DOCKER_REMOVE_DELAY=30mins
MESOS_DOCKER_STOP_TIMEOUT=1mins


echo -n "Mesos Slave (${MESOS_SLAVE_IP}) "
docker run -d --rm -it --ip ${MESOS_SLAVE_IP} \
  --name asgard_mesosslave \
  --net ${NETWORK_NAME} \
  --env-file <(
echo MESOS_IP=${MESOS_IP}
echo LIBPROCESS_ADVERTISE_IP=${LIBPROCESS_ADVERTISE_IP}
echo MESOS_ATTRIBUTES=${MESOS_ATTRIBUTES}
echo MESOS_MASTER=${MESOS_MASTER}
echo MESOS_EXECUTOR_REGISTRATION_TIMEOUT=${MESOS_EXECUTOR_REGISTRATION_TIMEOUT}
echo MESOS_CONTAINERIZERS=${MESOS_CONTAINERIZERS}
echo MESOS_HOSTNAME_LOOKUP=${MESOS_HOSTNAME_LOOKUP}
echo MESOS_GC_DELAY=${MESOS_GC_DELAY}
echo MESOS_SWITCH_USER=${MESOS_SWITCH_USER}
echo MESOS_SYSTEMD_ENABLE_SUPPORT=${MESOS_SYSTEMD_ENABLE_SUPPORT}
echo MESOS_DOCKER_REMOVE_DELAY=${MESOS_DOCKER_REMOVE_DELAY}
echo MESOS_DOCKER_STOP_TIMEOUT=${MESOS_DOCKER_STOP_TIMEOUT}
) \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/docker.tar.bz2:/etc/docker.tar.bz2 \
  docker.sieve.com.br/centos7/mesos:0.0.3



## MARATHON
MARATHON_HOSTNAME=${MARATHON_IP}
MESOS_IP=${MARATHON_IP}
LIBPROCESS_IP=${MARATHON_IP}
MARATHON_MASTER=zk://${ZK_CLUSTER_IPS}/mesos
MARATHON_ZK=zk://${ZK_CLUSTER_IPS}/mesos
MARATHON_TASK_LOST_EXPUNGE_GC=150000
MARATHON_TASK_LOST_EXPUNGE_INTERVAL=3600000
MARATHON_TASK_LOST_EXPUNGE_INITIAL_DELAY=300000
MARATHON_TASK_LAUNCH_TIMEOUT=300000
MARATHON_RECONCILIATION_INITIAL_DELAY=15000
MARATHON_RECONCILIATION_INTERVAL=600000
MARATHON_ZK_TIMEOUT=10000
MARATHON_ZK_SESSION_TIMEOUT=10000
MARATHON_ZK_MAX_VERSIONS=25
JAVA_OPTS=-Xms2g
MARATHON_HTTP_CREDENTIALS=marathon:pwd
MARATHON_ACCESS_CONTROL_ALLOW_ORIGIN=http://localhost:4200

echo -n "Marathon (${MARATHON_IP}) "
docker run -d --rm -it --ip ${MARATHON_IP} \
  --name asgard_marathon \
  --net ${NETWORK_NAME} \
  --env-file <(
echo MARATHON_HOSTNAME=${MARATHON_HOSTNAME}
echo MESOS_IP=${MESOS_IP}
echo LIBPROCESS_IP=${LIBPROCESS_IP}
echo MARATHON_MASTER=${MARATHON_MASTER}
echo MARATHON_ZK=${MARATHON_ZK}
echo MARATHON_TASK_LOST_EXPUNGE_GC=${MARATHON_TASK_LOST_EXPUNGE_GC}
echo MARATHON_TASK_LOST_EXPUNGE_INTERVAL=${MARATHON_TASK_LOST_EXPUNGE_INTERVAL}
echo MARATHON_TASK_LOST_EXPUNGE_INITIAL_DELAY=${MARATHON_TASK_LOST_EXPUNGE_INITIAL_DELAY}
echo MARATHON_TASK_LAUNCH_TIMEOUT=${MARATHON_TASK_LAUNCH_TIMEOUT}
echo MARATHON_RECONCILIATION_INITIAL_DELAY=${MARATHON_RECONCILIATION_INITIAL_DELAY}
echo MARATHON_RECONCILIATION_INTERVAL=${MARATHON_RECONCILIATION_INTERVAL}
echo MARATHON_ZK_TIMEOUT=${MARATHON_ZK_TIMEOUT}
echo MARATHON_ZK_SESSION_TIMEOUT=${MARATHON_ZK_SESSION_TIMEOUT}
echo MARATHON_ZK_MAX_VERSIONS=${MARATHON_ZK_MAX_VERSIONS}
echo JAVA_OPTS=${JAVA_OPTS}
#echo #MARATHON_HTTP_CREDENTIALS=${MARATHON_HTTP_CREDENTIALS}
echo MARATHON_ACCESS_CONTROL_ALLOW_ORIGIN=${MARATHON_ACCESS_CONTROL_ALLOW_ORIGIN}
) \
  mesosphere/marathon:v1.3.13 --enable_features gpu_resources

echo "Pressione ENTER para desligar o ambiente"
echo "ATENÇÃO: Todos os dados serão perdidos"
read
docker rm -f $(docker ps -aq -f name=asgard_)
