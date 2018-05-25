#!/bin/bash
# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

set -e

prepare_database() {
  RAILSPKG_DATABASE_LOAD_TASK="$1"
  DB_MIGRATE_STATUS=$($COMMAND_PREFIX bundle exec rake db:migrate:status 2>&1 || true)
  if echo "$DB_MIGRATE_STATUS" | grep -qF 'Schema migrations table does not exist yet.'; then
      # The database exists, but the migrations table doesn't.
      bundle exec rake "$RAILSPKG_DATABASE_LOAD_TASK" db:seed
  elif echo "$DB_MIGRATE_STATUS" | grep -q '^database: '; then
      bundle exec rake db:migrate
  elif echo "$DB_MIGRATE_STATUS" | grep -q 'database .* does not exist'; then
      bundle exec rake db:setup
  else
    echo "Warning: Database is not ready to set up." >&2
    exit 1
  fi
}

prepare_database "db:schema:load"
