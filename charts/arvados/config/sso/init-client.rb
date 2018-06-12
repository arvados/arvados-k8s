# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

c = Client.new
c.name = "joshid"
c.app_id = "arvados-server"
c.app_secret = "app_secret"
c.save!

User.find_or_create_by_email(email: "{{ .Values.adminUserEmail }}") do |user|
  user.password = "{{ .Values.adminUserPassword }}"
end
