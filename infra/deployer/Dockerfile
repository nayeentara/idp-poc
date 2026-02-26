FROM hashicorp/terraform:1.9.4

RUN apk add --no-cache bash curl jq aws-cli kubectl

WORKDIR /workspace

COPY deploy.sh /workspace/deploy.sh

ENTRYPOINT ["/bin/bash", "/workspace/deploy.sh"]
