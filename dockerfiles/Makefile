# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: AGPL-3.0

REPO = cure
REBUILD=

all: build push

rebuild: REBUILD="--no-cache"
rebuild: build

build: docker-build-arvados-runtime docker-build-arvados-rails-runtime docker-build-arvados-slurm-runtime docker-build-arvados-shell-server-runtime

push: docker-push-arvados-runtime docker-push-arvados-rails-runtime docker-push-arvados-slurm-runtime docker-push-arvados-shell-server-runtime

docker-build-arvados-runtime:
	docker build ${REBUILD} -t ${REPO}/arvados-runtime -f Dockerfile.runtime .

docker-push-arvados-runtime: docker-build-arvados-runtime
	docker push ${REPO}/arvados-runtime:latest

docker-build-arvados-rails-runtime:
	docker build ${REBUILD} -t ${REPO}/arvados-rails-runtime -f Dockerfile.rails-runtime .

docker-push-arvados-rails-runtime: docker-build-arvados-rails-runtime
	docker push ${REPO}/arvados-rails-runtime:latest

docker-build-arvados-slurm-runtime:
	docker build ${REBUILD} -t ${REPO}/arvados-slurm-runtime -f Dockerfile.slurm-runtime .

docker-push-arvados-slurm-runtime: docker-build-arvados-slurm-runtime
	docker push ${REPO}/arvados-slurm-runtime:latest

docker-build-arvados-shell-server-runtime:
	docker build ${REBUILD} -t ${REPO}/arvados-shell-server-runtime -f Dockerfile.shell_server-runtime .

docker-push-arvados-shell-server-runtime: docker-build-arvados-shell-server-runtime
	docker push ${REPO}/arvados-shell-server-runtime:latest
