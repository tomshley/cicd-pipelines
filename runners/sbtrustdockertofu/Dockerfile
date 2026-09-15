# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM toolbox_docker_build_ref AS toolbox
FROM --platform=$TARGETPLATFORM entry_docker_cli_buildx_docker_build_ref AS docker-tools
FROM --platform=$TARGETPLATFORM lang_java_jdk_docker_build_ref AS jdk
FROM --platform=$TARGETPLATFORM entry_sbt_docker_build_ref AS sbt
FROM --platform=$TARGETPLATFORM entry_opentofu_docker_build_ref AS opentofu
FROM --platform=$TARGETPLATFORM entry_rust_docker_build_ref AS rust
FROM --platform=$TARGETPLATFORM entry_zig_docker_build_ref AS zig
FROM --platform=$TARGETPLATFORM os_docker_build_ref

ENV PYTHONUNBUFFERED=1

ARG BINARIES_PREFIX="/opt"
ARG RUST_VERSION="1.98.1"
ARG CARGO_ZIGBUILD_VERSION="0.23.3"

COPY --from=toolbox /opt/tomshley-cicd-pipelines-toolbox/ /opt/tomshley-cicd-pipelines-toolbox/
COPY --from=docker-tools /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker-tools /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
COPY --from=jdk /usr/lib/jvm/java-21-openjdk/ ${BINARIES_PREFIX}/jdk/
COPY --from=sbt ${BINARIES_PREFIX}/sbt/ ${BINARIES_PREFIX}/sbt/
COPY --from=opentofu /usr/bin/tofu /usr/local/bin/tofu
COPY --from=rust ${BINARIES_PREFIX}/rust/ ${BINARIES_PREFIX}/rust/
COPY --from=zig ${BINARIES_PREFIX}/zig/ ${BINARIES_PREFIX}/zig/

ENV JAVA_HOME=${BINARIES_PREFIX}/jdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

ENV SBT_HOME=${BINARIES_PREFIX}/sbt
ENV PATH="${SBT_HOME}/bin:${PATH}"

ENV CARGO_HOME=/root/.cargo
ENV RUSTUP_HOME=/root/.rustup
ENV PATH="/root/.cargo/bin:${BINARIES_PREFIX}/rust/bin:${BINARIES_PREFIX}/zig:${PATH}"

# ---- Cross-compilation: rustup + Darwin targets + cargo-zigbuild ----
# Rustup installs the same Rust version as the entry image so it
# can manage cross-compilation targets (linked toolchains can't do this).
# The vendored /opt/rust stays intact as a fallback on PATH.
# cargo-zigbuild is pinned alongside Rust and Zig for cross-compilation.
# Update the entry-image references when changing this toolchain.
RUN set -eux; \
    apk update; \
    apk upgrade; \
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
      python3; \
    rm -rf /var/cache/*; \
    mkdir /var/cache/apk -p; \
    ln -sf python3 /usr/bin/python; \
    ln -sf /etc/ssl/certs/java/cacerts ${JAVA_HOME}/lib/security/cacerts; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --default-toolchain "${RUST_VERSION}"; \
    rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-unknown-linux-musl aarch64-unknown-linux-musl aarch64-apple-darwin x86_64-apple-darwin x86_64-pc-windows-gnu; \
    cargo install "cargo-zigbuild@${CARGO_ZIGBUILD_VERSION}" --locked; \
    rm -rf /tmp/* /root/.rustup/tmp

WORKDIR /
ENTRYPOINT []
