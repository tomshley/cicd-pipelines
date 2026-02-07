# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

ARG TOMSHLEY_DOCKERS_BUILD_REF
FROM --platform=$BUILDPLATFORM docker/buildx-bin:v0.21 AS buildx-bin
FROM --platform=$BUILDPLATFORM lang_java_jdk_docker_build_ref AS jdk
FROM --platform=$BUILDPLATFORM tools_provisioning_cicd_gitlab_scripts AS cicd-gitlab-scripts
FROM --platform=$BUILDPLATFORM tools_base_docker_build_ref

ENV PYTHONUNBUFFERED=1

ARG BINARIES_PREFIX="/opt"
ARG TMP_DIR="/tmp"
ARG SBT_VERSION="1.10.2"

COPY --from=buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=jdk ${BINARIES_PREFIX}/* ${BINARIES_PREFIX}/jdk/
COPY --from=jdk /etc/java-21-openjdk/ /etc/java-21-openjdk/
COPY --from=cicd-gitlab-scripts /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/. /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/

ENV JAVA_HOME=${BINARIES_PREFIX}/jdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

ENV SBT_HOME=${BINARIES_PREFIX}/sbt
ENV PATH="${SBT_HOME}/bin:${PATH}"

RUN echo '@edge http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
    echo '@community http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add --no-cache \
      bash \
      gawk \
      jq \
      openssl \
      make \
      curl \
      openssh \
      gcompat \
      git-flow \
      git-lfs \
      git \
      python3 && \
    apk add --no-cache \
      docker@community \
      docker-cli-buildx@community \
      docker-cli-compose@community && \
    apk add --no-cache \
      opentofu@testing && \
    mkdir -p ${SBT_HOME} && \
    wget -qO /tmp/sbt.tgz "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" && \
    tar xzf /tmp/sbt.tgz -C ${SBT_HOME} --strip-components=1 && \
    rm -f /tmp/sbt.tgz && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    cd /usr/local/bin && \
    ln -sf python3 /usr/bin/python && \
    ln -s /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/* .

WORKDIR /
ENTRYPOINT []
