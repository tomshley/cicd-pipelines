# Copyright (c) 2024–2026 Tomshley
#
# Licensed under the Apache License, Version 2.0
#
# Toolbox OCI image — contains cicd-pipelines scripts.
# This image is NOT run directly. It is used as a COPY --from= source
# in runner Dockerfiles to bake scripts into runner images.
#
# The base image (os_docker_build_ref) is supplied by docker-bake.hcl
# pointing to base-alpine-3_23-upstream — the same base every runner uses.

FROM --platform=$BUILDPLATFORM os_docker_build_ref

RUN apk add --no-cache bash

COPY scripts/tomshley-cicd-pipelines-toolbox/ /opt/tomshley-cicd-pipelines-toolbox/

RUN find /opt/tomshley-cicd-pipelines-toolbox -name '*.sh' -exec chmod +x {} +
RUN find /opt/tomshley-cicd-pipelines-toolbox -name '*.sh' -exec bash -n {} +
