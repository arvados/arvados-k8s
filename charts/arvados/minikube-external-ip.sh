#!/bin/bash

# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

EXTERNAL_IP=$1

if [[ -z "$EXTERNAL_IP" ]]; then
  EXTERNAL_IP=`minikube ip`
fi

if [[ -z "$EXTERNAL_IP" ]]; then
  echo "Syntax: $0 <external_ip>"
  echo "I tried running `minikube ip` but that failed"
  exit 1
fi

kubectl patch service arvados-api-server -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$EXTERNAL_IP\"]}}"
kubectl patch service arvados-keep-proxy -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$EXTERNAL_IP\"]}}"
kubectl patch service arvados-keep-web -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$EXTERNAL_IP\"]}}"
kubectl patch service arvados-workbench -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$EXTERNAL_IP\"]}}"
kubectl patch service arvados-ws -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$EXTERNAL_IP\"]}}"

