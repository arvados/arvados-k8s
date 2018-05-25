# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

c = Client.new
c.name = "joshid"
c.app_id = "arvados-server"
c.app_secret = "app_secret"
c.save!

User.find_or_create_by_email(email: "test@example.com") do |user|
  user.password = "passw0rd"
end
