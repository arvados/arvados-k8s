# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0

include CurrentApiClient
act_as_system_user do
  wb = ApiClient.new(:url_prefix => "{{ .Values.externalIP }}")
  wb.save!
  wb.update_attributes!(is_trusted: true)
end
