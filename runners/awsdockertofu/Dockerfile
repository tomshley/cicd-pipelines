# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM toolbox_docker_build_ref AS toolbox
FROM --platform=$BUILDPLATFORM entry_docker_cli_buildx_docker_build_ref AS docker-tools
FROM --platform=$BUILDPLATFORM entry_opentofu_docker_build_ref AS opentofu
FROM --platform=$BUILDPLATFORM os_docker_build_ref

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

ARG BINARIES_PREFIX="/opt"

COPY --from=toolbox /opt/tomshley-cicd-pipelines-toolbox/ /opt/tomshley-cicd-pipelines-toolbox/
COPY --from=docker-tools /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
COPY --from=opentofu /usr/bin/tofu /usr/local/bin/tofu

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      bash \
      ca-certificates \
      gawk \
      iptables \
      libseccomp \
      jq \
      openssl \
      make \
      curl \
      openssh \
      gcompat \
      git-flow \
      git-lfs \
      git \
      python3 \
      py3-pip && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    ln -sf python3 /usr/bin/python && \
    pip3 install --no-cache-dir "awscli>=1.34,<2" && \
    aws --version

WORKDIR /
ENTRYPOINT []
