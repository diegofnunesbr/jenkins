FROM jenkins/jenkins:2.568.3-jdk21

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        python3 \
        python3-pip \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --no-cache-dir ansible==14.4.0

RUN curl -fsSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.16.3/terraform_1.16.3_linux_amd64.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

RUN curl -fsSL -o /tmp/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v1.1.5/terragrunt_linux_amd64" \
    && install -m 0755 /tmp/terragrunt /usr/local/bin/terragrunt \
    && rm /tmp/terragrunt

USER jenkins
