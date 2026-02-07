# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM os_docker_build_ref

RUN echo '@edge http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add --no-cache \
        iptables@edge \
        libseccomp@edge \
        jq@edge \
        openssl@edge \
        make@edge \
        curl@edge \
        openssh@edge \
        gcompat@edge && \
    rm -rf /var/cache/* && \
    mkdir /var/cache/apk -p && \
    cd /usr/local/bin && apk info -L

WORKDIR /
ENTRYPOINT []
