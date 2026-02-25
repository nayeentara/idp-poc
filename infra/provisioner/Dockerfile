FROM hashicorp/terraform:1.9.4

RUN apk add --no-cache bash curl jq aws-cli

WORKDIR /workspace

COPY terraform /workspace/terraform
COPY provision.sh /workspace/provision.sh

ENV TF_IN_AUTOMATION=1

ENTRYPOINT ["/bin/bash", "/workspace/provision.sh"]
