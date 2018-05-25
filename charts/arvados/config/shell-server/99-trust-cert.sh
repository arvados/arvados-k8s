#!/bin/bash
# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

cat /self-signed-cert.pem >> /etc/ssl/certs/ca-certificates.crt
