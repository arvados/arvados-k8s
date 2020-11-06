#!/bin/bash
# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

function create_user_and_database() {
  local database=$1
  local user=$2
  local password=$3
  echo "Creating database '$database'"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
      CREATE USER $user WITH CREATEDB PASSWORD '$password';
      CREATE DATABASE $database OWNER $user;
EOSQL
  psql -v ON_ERROR_STOP=1 "$database" --username "$POSTGRES_USER" <<-EOSQL
      CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
EOSQL
}

create_user_and_database arvados_production arvados pw

