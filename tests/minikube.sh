#!/bin/bash

set -e

DEBUG=$1
CLUSTERTYPE="minikube"

. test_library.sh

loadK8sIP() {
  set +e
  K8S_IP=`minikube ip 2>/dev/null`
  if [[ $? -ne 0 ]]; then
    K8S_IP=
  fi
  set -e
}

stopK8s() {
  echo "Stopping Minikube"
  minikube stop
}

startK8s() {
  echo "Starting Minikube"
  minikube start
  loadK8sIP
}

run
