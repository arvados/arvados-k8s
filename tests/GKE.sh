#!/bin/bash

# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

set -e

DEBUG=$1
CLUSTERTYPE="GKE"

. test_library.sh

loadK8sIP() {
  set +e
  K8S_IP=`gcloud compute addresses describe arvados-k8s-ip --region us-central1 --format="value(address)" 2>/dev/null`
  if [[ $? -ne 0 ]]; then
    K8S_IP=
  fi
  set -e
}

stopK8s() {
  echo "Stopping k8s cluster on GKE"
  gcloud container clusters delete arvados --zone us-central1-a --quiet
  gcloud compute addresses delete arvados-k8s-ip --region us-central1 --quiet
}

startK8s() {
  echo "Starting k8s cluster on GKE"
  if [[ -z "$K8S_IP" ]]; then
    gcloud compute addresses create arvados-k8s-ip --region us-central1
    loadK8sIP
  fi
  set +e
  CLUSTER=`gcloud container clusters describe arvados --zone us-central1-a 2>/dev/null`
  set -e
  if [[ -z "$CLUSTER" ]]; then
    gcloud container clusters create arvados --zone us-central1-a --machine-type n1-standard-2
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
}

run
