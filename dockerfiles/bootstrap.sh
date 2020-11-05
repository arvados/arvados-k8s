#!/bin/bash

# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

if [[ "$1" == "" ]]; then
  echo "Syntax: $0 <package=version> [package=version] [gem:package=version] ..."
  exit 1
fi

if [[ "$@" =~ "arvados-workbench=" ]] || [[ "$@" =~ "arvados-sso-server=" ]] || [[ "$@" =~ "arvados-api-server=" ]]; then
  RESET_NGINX_DAEMON_FLAG=true
else
  RESET_NGINX_DAEMON_FLAG=false
fi

gems=()
debs=()
for var in "$@"; do
  if [[ "$var" =~ "gem:" ]]; then
    cleanvar=${var#gem:}
    gems+=" $cleanvar"
  else
    debs+=" $var"
  fi
done

if [[ "$RESET_NGINX_DAEMON_FLAG" == true ]]; then
  # our packages restart nginx; with the 'daemon off' flag in place, 
  # that makes package install hang. Arguably we shouldn't be restarting nginx on install.
  sed -i 's/daemon off;/#daemon off;/' /etc/nginx/nginx.conf
fi

if [[ "$debs" != "" ]]; then
  apt-get -qqy --allow-downgrades install $debs
  if [[ "$?" != "0" ]]; then
    # Maybe we need to update the apt cache first?
    apt-get update
    apt-get -qqy --allow-downgrades install $debs
  fi
fi

if [[ "$gems" != "" ]]; then
  for var in $gems; do
    IFS='=' arr=($var)
    gem install ${arr[0]} -v ${arr[1]} --no-rdoc --no-ri
  done
fi

if [[ "$RESET_NGINX_DAEMON_FLAG" == true ]]; then
  /etc/init.d/nginx stop
  sed -i 's/#daemon off;/daemon off;/' /etc/nginx/nginx.conf
fi
