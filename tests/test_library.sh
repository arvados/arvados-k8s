#!/bin/bash

if [[ "$DEBUG" == "--debug" ]]; then
  set -x
fi

testReady() {
  loadK8sIP
  set +e
  ready=0
  k8sReady=0
  apiReady=0
  keepProxyReady=0

  # Is k8s ready?
  if [[ -n "$K8S_IP" ]]; then
    k8sReady=1
  else
    set -e
    return
  fi

  # Is the Arvados API server ready?
  curl --connect-timeout 1 -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://$K8S_IP:444/rails/_health/ping |grep -q OK
  if [[ $? -eq 0 ]]; then
    apiReady=1
  else
    set -e
    return
  fi

  # Is the Arvados Keep proxy ready?
  curl --connect-timeout 1 -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://$K8S_IP:25107/_health/ping |grep -q OK
  if [[ $? -eq 0 ]]; then
    keepProxyReady=1
  else
    set -e
    return
  fi

  # Everything is working
  ready=1
  set -e
}

stopCluster() {
  echo "Stopping Arvados cluster..."
  cd $MY_PATH/../charts/arvados
  helm delete arvados

  stopK8s
}

kubectlStatus() {
  echo "Current k8s status:"
  echo "services:"
  kubectl get svc
  echo "pods:"
  kubectl get pods
  echo
}

startCluster() {
  startK8s

  echo "Starting Arvados cluster..."
  cd $MY_PATH/../charts/arvados
  ./cert-gen.sh "$K8S_IP"

  helm install arvados . --set externalIP="$K8S_IP"

  if [[ "$CLUSTERTYPE" == "minikube" ]]; then
    ./minikube-external-ip.sh
  fi

  awaitHealthOK
}

awaitHealthOK() {
  echo "Waiting for cluster health OK..."
  while [ $ready -ne 1 ]; do
    testReady
    kubectlStatus
    sleep 2
  done
}

run() {
  MY_PATH=`pwd`
  MANAGEMENTTOKEN=`cat $MY_PATH/../charts/arvados/config/config.yml |grep Management |cut -f2 -d ':' |sed -e 's/ //'`
  date
  testReady
  if [[ $ready -ne 1 ]]; then
    startCluster
  else
    if [[ "$CLUSTERTYPE" == "GKE" ]]; then
      # create the necessary kubectl context for the running cluster
      gcloud container clusters get-credentials arvados --zone us-central1-a
      kubectlStatus
    fi
  fi

  date
  echo "cluster health OK"

  export ARVADOS_API_HOST=$K8S_IP:444
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
