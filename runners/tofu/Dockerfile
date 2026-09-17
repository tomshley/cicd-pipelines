# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM toolbox_docker_build_ref AS toolbox
FROM --platform=$BUILDPLATFORM entry_opentofu_docker_build_ref AS opentofu
FROM --platform=$BUILDPLATFORM os_docker_build_ref

ARG BINARIES_PREFIX="/opt"

COPY --from=toolbox /opt/tomshley-cicd-pipelines-toolbox/ /opt/tomshley-cicd-pipelines-toolbox/
COPY --from=opentofu /usr/bin/tofu /usr/local/bin/tofu

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      bash \
      ca-certificates \
      gawk \
      jq \
      openssl \
      make \
      curl \
      openssh \
      gcompat \
      git-flow \
      git-lfs \
      git && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    tofu version

WORKDIR /
ENTRYPOINT []
