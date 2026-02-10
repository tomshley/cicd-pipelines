# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM entry_docker_cli_buildx_docker_build_ref AS docker-tools
FROM --platform=$BUILDPLATFORM lang_java_jdk_docker_build_ref AS jdk
FROM --platform=$BUILDPLATFORM entry_sbt_docker_build_ref AS sbt
FROM --platform=$BUILDPLATFORM entry_opentofu_docker_build_ref AS opentofu
FROM --platform=$BUILDPLATFORM entry_rust_docker_build_ref AS rust
FROM --platform=$BUILDPLATFORM os_docker_build_ref

ENV PYTHONUNBUFFERED=1

ARG BINARIES_PREFIX="/opt"

COPY --from=docker-tools /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
COPY --from=jdk /usr/lib/jvm/java-21-openjdk/ ${BINARIES_PREFIX}/jdk/
COPY --from=sbt ${BINARIES_PREFIX}/sbt/ ${BINARIES_PREFIX}/sbt/
COPY --from=opentofu /usr/bin/tofu /usr/local/bin/tofu
COPY --from=rust ${BINARIES_PREFIX}/rust/ ${BINARIES_PREFIX}/rust/

ENV JAVA_HOME=${BINARIES_PREFIX}/jdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

ENV SBT_HOME=${BINARIES_PREFIX}/sbt
ENV PATH="${SBT_HOME}/bin:${PATH}"

ENV CARGO_HOME=${BINARIES_PREFIX}/rust
ENV PATH="${BINARIES_PREFIX}/rust/bin:${PATH}"

RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      bash \
      ca-certificates \
      java-cacerts \
      gawk \
      iptables \
      libseccomp \
      jq \
      openssl \
      make \
      curl \
      openssh \
      gcompat \
      build-base \
      musl-dev \
      git-flow \
      git-lfs \
      git \
      python3 && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    ln -sf python3 /usr/bin/python && \
    ln -sf /etc/ssl/certs/java/cacerts ${JAVA_HOME}/lib/security/cacerts

WORKDIR /
ENTRYPOINT []
