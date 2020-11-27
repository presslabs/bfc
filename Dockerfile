FROM buildpack-deps:stretch as bfc-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV HOME=/root
WORKDIR /root

# install unzip
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        zip=3.0* unzip=6.0* apt-transport-https=1.4* \
    && rm -rf /var/lib/apt/lists/*

# install php
RUN curl -ssL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ stretch main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php7.2-cli php-pear \
    && rm -rf /var/lib/apt/lists/*

# install goenv and go
ENV GOENV_TOOL_VERSION=f914e34
ENV GOENV_ROOT="${HOME}/.goenv"
ENV GO_VERSIONS="1.14.1"
ENV GO_DEP_VERSION="0.5.4"
ENV GOENV_DISABLE_GOPATH=1
RUN curl -sL -o /tmp/goenv.tar.gz "https://github.com/syndbg/goenv/archive/${GOENV_TOOL_VERSION}.tar.gz" \
    && mkdir -p "${GOENV_ROOT}" \
    && tar -zxf /tmp/goenv.tar.gz -C "${GOENV_ROOT}" --strip-components=1 \
    && rm /tmp/goenv.tar.gz \
    && for v in ${GO_VERSIONS} ; do ./.goenv/bin/goenv install $v ; done \
    && ./.goenv/bin/goenv global "$(echo "${GO_VERSIONS}" | awk '{print $1}')" \
    && curl -sL -o dep-install "https://raw.githubusercontent.com/golang/dep/master/install.sh" \
    && INSTALL_DIRECTORY=/usr/local/bin DEP_RELEASE_TAG="v${GO_DEP_VERSION}" sh dep-install \
    && rm dep-install

# install nodenv and node
ENV NODENV_TOOL_VERSION=1.1.2
ENV NODENV_BUILD_TOOL_VERSION=4.4.5
ENV NODENV_DEFAULT_PKGS_TOOL_VERSION=0.2.1
ENV NODENV_ROOT="${HOME}/.nodenv"
ENV NODE_VERSIONS="10.15.3"
RUN curl -sL -o /tmp/nodenv.tar.gz "https://github.com/nodenv/nodenv/archive/v${NODENV_TOOL_VERSION}.tar.gz" \
    && mkdir -p "${NODENV_ROOT}" \
    && tar -zxf /tmp/nodenv.tar.gz -C "${NODENV_ROOT}" --strip-components=1 \
    && rm /tmp/nodenv.tar.gz \
    && mkdir -p "${NODENV_ROOT}/plugins/node-build" \
    && curl -sL "https://github.com/nodenv/node-build/archive/v${NODENV_BUILD_TOOL_VERSION}.tar.gz" | \
        tar -zxf - -C "${NODENV_ROOT}/plugins/node-build" --strip-components=1 \
    && mkdir -p "${NODENV_ROOT}/plugins/nodenv-default-packages" \
    && curl -sL "https://github.com/nodenv/nodenv-default-packages/archive/v${NODENV_DEFAULT_PKGS_TOOL_VERSION}.tar.gz" | \
        tar -zxf - -C "${NODENV_ROOT}/plugins/nodenv-default-packages" --strip-components=1 \
    && { \
         echo "yarn"; \
         echo "grunt-cli"; \
         echo "gulp-cli"; \
    } > ${NODENV_ROOT}/default-packages \
    && for v in ${NODE_VERSIONS} ; do ./.nodenv/bin/nodenv install $v ; done \
    && ./.nodenv/bin/nodenv global "$(echo "${NODE_VERSIONS}" | awk '{print $1}')"

# install pyenv and python
ENV PYENV_TOOL_VERSION=1.2.11
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PYTHON_VERSIONS="3.7.3 2.7.16"
RUN curl -sL -o /tmp/pyenv.tar.gz "https://github.com/pyenv/pyenv/archive/v${PYENV_TOOL_VERSION}.tar.gz" \
    && mkdir -p "${PYENV_ROOT}" \
    && tar -zxf /tmp/pyenv.tar.gz -C "${PYENV_ROOT}" --strip-components=1 \
    && rm /tmp/pyenv.tar.gz \
    && for v in ${PYTHON_VERSIONS} ; do ./.pyenv/bin/pyenv install $v ; done \
    && ./.pyenv/bin/pyenv global \
        "$(echo "${PYTHON_VERSIONS}" | grep -Eo \\b2.[[:digit:]]+.[[:digit:]]+ | head -n1)" \
        "$(echo "${PYTHON_VERSIONS}" | grep -Eo \\b3.[[:digit:]]+.[[:digit:]]+ | head -n1)"

ENV GOPATH="${HOME}/go"
ENV PATH="${PYENV_ROOT}/shims:${NODENV_ROOT}/shims:${GOENV_ROOT}/shims:/home/build/bin:${GOPATH}/bin:${PYENV_ROOT}/bin:${NODENV_ROOT}/bin:${GOENV_ROOT}/bin:${PATH}"
RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin ${GOPATH}/pkg

################################################################################

FROM bfc-base as bfc
ENV PYTHONUNBUFFERED 1

ENV JQ_VERSION="1.6"
RUN curl -sL -o /usr/local/bin/jq "https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" \
    && chmod 0755 /usr/local/bin/jq \
    && chown root:root /usr/local/bin/jq

ENV YQ_VERSION="3.4.1"
RUN curl -sL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    && chmod 0755 /usr/local/bin/yq \
    && chown root:root /usr/local/bin/yq

# install dockerize for templating support
ENV DOCKERIZE_VERSION="1.3.0"
RUN curl -sL -o dockerize.tar.gz "https://github.com/presslabs/dockerize/releases/download/v${DOCKERIZE_VERSION}/dockerize-linux-amd64-v${DOCKERIZE_VERSION}.tar.gz" \
    && tar -C /usr/local/bin -xzvf dockerize.tar.gz \
    && rm dockerize.tar.gz \
    && chmod 0755 /usr/local/bin/dockerize \
    && chown root:root /usr/local/bin/dockerize

# install prototool for protobuf related work
ENV PROTOTOOL_VERSION="1.9.0"
RUN curl -sL -o /usr/local/bin/prototool "https://github.com/uber/prototool/releases/download/v${PROTOTOOL_VERSION}/prototool-Linux-x86_64" \
    && chmod +x /usr/local/bin/prototool

# install mozilla sops
ENV SOPS_VERSION="v3.6.1"
RUN curl -sL -o /usr/local/bin/sops "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" \
    && chmod 0755 /usr/local/bin/sops \
    && chown root:root /usr/local/bin/sops

# install kubernetes helm
ENV HELM_VERSION="3.2.4"
RUN curl -sL -o helm.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -C /usr/local/bin -xzvf helm.tar.gz --strip-components 1 linux-amd64/helm \
    && rm helm.tar.gz \
    && chmod 0755 /usr/local/bin/helm \
    && chown root:root /usr/local/bin/helm

# install helm secrets plugin
RUN helm plugin install https://github.com/futuresimple/helm-secrets \
    && helm repo add presslabs https://presslabs.github.io/charts \
    && helm repo add kubes https://presslabs-kubes.github.io/charts

# install kubectl
ENV KUBECTL_VERSION="1.15.1"
RUN curl -sL -o /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v{$KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod 0755 /usr/local/bin/kubectl \
    && chown root:root /usr/local/bin/kubectl

# install kustomize
ENV KUSTOMIZE_VERSION="3.8.4"
RUN curl -sL -o kustomize.tar.gz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
    && tar -C /usr/local/bin -xzvf kustomize.tar.gz \
    && rm kustomize.tar.gz \
    && chmod 0755 /usr/local/bin/kustomize \
    && chown root:root /usr/local/bin/kustomize

# install docker
ENV DOCKER_VERSION="18.09.8"
RUN set -ex \
    && curl -sL -o docker.tar.gz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    && tar -C /usr/local/bin -xzvf docker.tar.gz --strip-components 1 docker/docker \
    && rm docker.tar.gz \
    && chmod +x /usr/local/bin/docker \
    && chown root:root /usr/local/bin/docker

# install docker-compose
ENV DOCKER_COMPOSE_VERSION="1.24.1"
RUN set -ex \
    && curl -sL -o /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64" \
    && chmod +x /usr/local/bin/docker-compose \
    && chown root:root /usr/local/bin/docker

# https://cloud.google.com/sdk/docs/downloads-versioned-archives
ENV GCLOUD_SDK_VERSION="254.0.0"
ENV CLOUDSDK_PYTHON="/usr/bin/python2.7"
ENV GOOGLE_APPLICATION_CREDENTIALS="/run/google-credentials.json"
RUN curl -sL -o google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_SDK_VERSION}-linux-x86_64.tar.gz \
    && tar -zxf google-cloud-sdk.tar.gz \
    && mv google-cloud-sdk /opt/ \
    && rm google-cloud-sdk.tar.gz \
    && /opt/google-cloud-sdk/bin/gcloud --quiet components install beta

ENV RCLONE_VERSION="1.50.2"
RUN set -ex \
    && curl -sL -o rclone-v${RCLONE_VERSION}-linux-amd64.deb https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.deb \
    && dpkg -i rclone-v${RCLONE_VERSION}-linux-amd64.deb \
    && rm rclone-v${RCLONE_VERSION}-linux-amd64.deb

# install mysql-client, gettext
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends mysql-client gettext

# install composer
RUN set -ex \
    && curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

RUN pip3 install zipa pyyaml
COPY utils/ /usr/local/bin/

ENV KUBEBUILDER_VERSION="2.3.1"
ENV PATH="${PATH}:/usr/local/kubebuilder/bin"
RUN curl -sL -o kubebuilder.tar.gz https://github.com/kubernetes-sigs/kubebuilder/releases/download/v${KUBEBUILDER_VERSION}/kubebuilder_${KUBEBUILDER_VERSION}_linux_amd64.tar.gz \
    && mkdir -p /usr/local/kubebuilder \
    && tar -C /usr/local/kubebuilder -xzvf kubebuilder.tar.gz --strip-components=1 \
    && rm kubebuilder.tar.gz
