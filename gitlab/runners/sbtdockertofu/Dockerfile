#
# Copyright 2023 Tomshley LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @author Thomas Schena @sgoggles <https://github.com/sgoggles> | <https://gitlab.com/sgoggles>
#
ARG TOMSHLEY_DOCKERS_BUILD_REF
FROM --platform=$BUILDPLATFORM docker/buildx-bin:v0.11 as buildx-bin
FROM --platform=$BUILDPLATFORM lang_java_jdk_docker_build_ref as jdk
FROM --platform=$BUILDPLATFORM tools_provisioning_cicd_gitlab_scripts as cicd-gitlab-scripts
FROM --platform=$BUILDPLATFORM tools_base_docker_build_ref

ENV PYTHONUNBUFFERED=1

ARG BINARIES_PREFIX="/opt"
ARG TMP_DIR="/tmp"

COPY --from=buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=jdk ${BINARIES_PREFIX}/* ${BINARIES_PREFIX}/jdk/
COPY files/sbt-1.10.2.tgz ${TMP_DIR}/sbt-1.10.2.tgz
COPY --from=cicd-gitlab-scripts /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/. /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/

ENV JAVA_HOME=${BINARIES_PREFIX}/jdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"


# https://downloads.typesafe.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz
# wget -qO - --no-check-certificate "https://dl.bintray.com/sbt/native-packages/sbt/1.10.2/sbt-1.10.2.tgz" | tar xz -C /usr/local/sbt --strip-components=1
ENV SBT_HOME=${BINARIES_PREFIX}/sbt
ENV PATH "${SBT_HOME}/bin:${PATH}"

RUN echo '@edge http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
          echo '@community http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
          echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
          apk update && \
          apk upgrade && \
          apk add --no-cache &&  \
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
    tar xzvf  ${TMP_DIR}/sbt-1.10.2.tgz -C ${SBT_HOME} --strip-components=1 && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    cd /usr/local/bin && \
    ln -sf python3 /usr/bin/python && \
    ln -s /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/*/ .

WORKDIR /

# use this for direct access to TF, not for GitLab Usage: ENTRYPOINT ["terraform"]
ENTRYPOINT []
