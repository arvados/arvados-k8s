#!/bin/bash

set -e

testReady() {
  set +e
  ready=0
  apiReady=0
  keepProxyReady=0
  curl -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://`minikube ip`:444/rails/_health/ping |grep -q OK
  if [[ $? -eq 0 ]]; then
    apiReady=1
  fi
  curl -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://`minikube ip`:25107/_health/ping |grep -q OK
  if [[ $? -eq 0 ]]; then
    keepProxyReady=1
  fi
  if [[ $apiReady -eq 1 ]] && [[ $keepProxyReady -eq 1 ]]; then
    ready=1
  fi
  set -e
}

stopCluster() {
  echo "Stopping Arvados cluster..."
  cd $MY_PATH/../charts/arvados
  helm delete arvados

  echo "Stopping Minikube"
  minikube stop
}

startCluster() {
  echo "Starting Minikube"
  minikube start

  echo "Starting Arvados cluster..."
  cd $MY_PATH/../charts/arvados
  ./cert-gen.sh `minikube ip`

  helm install arvados . --set externalIP=`minikube ip`

  ./minikube-external-ip.sh

  echo "Waiting for cluster health OK..."
  while [ $ready -ne 1 ]; do
    testReady
    sleep 1
  done
}

main() {
  MY_PATH=`pwd`
  MANAGEMENTTOKEN=`cat $MY_PATH/../charts/arvados/config/config.yml |grep Management |cut -f2 -d ':' |sed -e 's/ //'`
  date
  testReady

  if [[ $ready -ne 1 ]]; then
    startCluster
  fi
  date
  echo "cluster health OK"
 
  export ARVADOS_API_HOST=`minikube ip`:444
  export ARVADOS_API_HOST_INSECURE=true
  export ARVADOS_API_TOKEN=`grep superUserSecret $MY_PATH/../charts/arvados/values.yaml |cut -f2 -d\"`

  cd $MY_PATH/cwl-diagnostics-hasher/

  echo "uploading requirements for CWL hasher"
  arv-put 4xphq-8i9sb-fmwod1qn74cemdp.log.txt  --no-resume
  echo "uploading Arvados jobs image for CWL hasher"
  # just in case, clear the arv-put cache first, arv-keepdocker doesn't pass through --no-resume
  rm -rf ~/.cache/arvados/arv-put
  echo "running CWL hasher"
  cwl-runner hasher-workflow.cwl hasher-workflow-job.yml
  if [[ $? -eq 0 ]]; then
    echo "Success!"
  else
    echo "Test failed!"
  fi

  stopCluster
}

main
