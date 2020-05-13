#!/bin/bash

set -e

DEBUG=$1

if [[ "$DEBUG" == "--debug" ]]; then
  set -x
fi

testReady() {
  set +e
  ready=0
  apiReady=0
  keepProxyReady=0
  curl --connect-timeout 1 -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://$GKE_IP:444/rails/_health/ping |grep -q OK
  if [[ $? -eq 0 ]]; then
    apiReady=1
  else
    return
  fi
  curl --connect-timeout 1 -k -s -H "Authorization: Bearer $MANAGEMENTTOKEN" https://$GKE_IP:25107/_health/ping |grep -q OK
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

  echo "Stopping k8s cluster on GKE"
  gcloud container clusters delete arvados --zone us-central1-a --quiet
  gcloud compute addresses delete arvados-k8s-ip --region us-central1 --quiet
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
  echo "Starting k8s cluster on GKE"
  if [[ -z "$GKE_IP" ]]; then
    gcloud compute addresses create arvados-k8s-ip --region us-central1
    GKE_IP=`gcloud compute addresses describe arvados-k8s-ip --region us-central1 --format="value(address)"`
  fi
  set +e
  CLUSTER=`gcloud container clusters describe arvados --zone us-central1-a 2>/dev/null`
  set -e
  if [[ -z "$CLUSTER" ]]; then
    gcloud container clusters create arvados --zone us-central1-a --machine-type n1-standard-2 --cluster-version 1.15
  fi

  set +e
  helm get all arvados >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "Deleting running arvados helm chart..."
    helm delete arvados
    while [ "$SVC" != "2" ]; do
      SVC=`kubectl get svc|wc -l`
      echo "Waiting for services to disappear..."
      kubectl get svc
      sleep 2
    done
  fi
  set -e

  echo "Starting Arvados cluster..."
  cd $MY_PATH/../charts/arvados
  ./cert-gen.sh "$GKE_IP"

  helm install arvados . --set externalIP="$GKE_IP"

  echo "Waiting for cluster health OK..."
  while [ $ready -ne 1 ]; do
    testReady
    kubectlStatus
    sleep 10
  done
}

main() {
  MY_PATH=`pwd`
  MANAGEMENTTOKEN=`cat $MY_PATH/../charts/arvados/config/config.yml |grep Management |cut -f2 -d ':' |sed -e 's/ //'`
  set +e
  GKE_IP=`gcloud compute addresses describe arvados-k8s-ip --region us-central1 --format="value(address)" 2>/dev/null`
  set -e
  date
  # testReady needs $GKE_IP
  testReady

  if [[ $ready -ne 1 ]]; then
    startCluster
  else
    # create the necessary kubectl context for the running cluster
    gcloud container clusters get-credentials arvados --zone us-central1-a
    kubectlStatus
  fi
  date
  echo "cluster health OK"

  export ARVADOS_API_HOST=$GKE_IP:444
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
