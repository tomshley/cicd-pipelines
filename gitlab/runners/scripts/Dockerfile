# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024–2026 Tomshley LLC

FROM --platform=$BUILDPLATFORM tools_base_docker_build_ref

COPY files/cicd-backends-local-validate.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-backends-local-validate.sh
COPY files/cicd-backends-remote-plan-apply.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-backends-remote-plan-apply.sh
COPY files/cicd-backends-remote-plan-no-lock.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-backends-remote-plan-no-lock.sh
COPY files/cicd-backends-remote-validate.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-backends-remote-validate.sh
COPY files/cicd-bootstrap-envvars-gitlab.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-envvars-gitlab.sh
COPY files/cicd-bootstrap-gitconfig.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitconfig.sh
COPY files/cicd-bootstrap-gitlfs.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlfs.sh
COPY files/cicd-bootstrap-gitlab-dockers.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlab-dockers.sh
COPY files/cicd-bootstrap-gitlab-gitconfig.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlab-gitconfig.sh
COPY files/cicd-bootstrap-gitlab-tf-backends-local.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlab-tf-backends-local.sh
COPY files/cicd-bootstrap-gitlab-tf-backends-remote.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlab-tf-backends-remote.sh
COPY files/cicd-bootstrap-gitlab.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-bootstrap-gitlab.sh
COPY files/cicd-dockers-build-push.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-dockers-build-push.sh
COPY files/cicd-dockers-build.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-dockers-build.sh
COPY files/cicd-exports.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-exports.sh
COPY files/cicd-flow-feature-gitlab-merge-request.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-feature-gitlab-merge-request.sh
COPY files/cicd-flow-feature-merge-upstream.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-feature-merge-upstream.sh
COPY files/cicd-flow-feature-update.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-feature-update.sh
COPY files/cicd-flow-hotfix-finish.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-hotfix-finish.sh
COPY files/cicd-flow-release-finish.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-release-finish.sh
COPY files/cicd-flow-release-publish.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-release-publish.sh
COPY files/cicd-flow-release-publish-prep.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-release-publish-prep.sh
COPY files/cicd-flow-release-start.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/cicd-flow-release-start.sh
COPY files/gitlab-terraform.sh /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/gitlab-terraform.sh

RUN chmod +x /opt/tomshley/provisioning/tools/cicd/gitlab/scripts/bin/*.sh

WORKDIR /
ENTRYPOINT []
