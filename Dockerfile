FROM golang:1.11-stretch as protobuf-build
ENV PROTOC_VERSION=3.6.1
ENV PROTOTOOL_VERSION=1.3.0
ENV PROTOC_GEN_GO_VERSION=1.2.0
ENV GRPC_VERSION=1.17.0
ENV PROTOC_GEN_LINT_VERSION=0.2.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        unzip=6.0*

WORKDIR /tmp

RUN curl -sL -o protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-$(uname -s)-$(uname -m).zip" \
    && unzip protoc.zip \
    && mv bin/* /go/bin \
    && git clone --depth=1 https://github.com/googleapis/googleapis \
    && mv googleapis/google/* include/google

RUN curl -sL -o /go/bin/prototool "https://github.com/uber/prototool/releases/download/v${PROTOTOOL_VERSION}/prototool-$(uname -s)-$(uname -m)" \
    && chmod +x /go/bin/prototool

RUN go get -d -u github.com/golang/protobuf/protoc-gen-go \
    && git -C ${GOPATH}/src/github.com/golang/protobuf checkout v${PROTOC_GEN_GO_VERSION} --quiet \
    && go install github.com/golang/protobuf/protoc-gen-go \
    && git -C ${GOPATH}/src/github.com/golang/protobuf checkout master --quiet

RUN go get -d -u google.golang.org/grpc \
    && git -C ${GOPATH}/src/google.golang.org/grpc checkout v${GRPC_VERSION} --quiet \
    && go install google.golang.org/grpc \
    && git -C ${GOPATH}/src/google.golang.org/grpc checkout master --quiet

RUN go get -d -u github.com/ckaznocha/protoc-gen-lint \
    && git -C ${GOPATH}/src/github.com/ckaznocha/protoc-gen-lint checkout v${PROTOC_GEN_LINT_VERSION} --quiet \
    && go install github.com/ckaznocha/protoc-gen-lint \
    && git -C ${GOPATH}/src/github.com/ckaznocha/protoc-gen-lint checkout master --quiet

RUN go get -u github.com/mwitkow/go-proto-validators/protoc-gen-govalidators
RUN go get -u github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc

################################################################################

FROM buildpack-deps:stretch as bfc-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=protobuf-build /go/bin/* /usr/local/bin/
COPY --from=protobuf-build /tmp/include/ /usr/local/include/

ENV HOME=/root
WORKDIR /root

# install unzip
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        unzip=6.0* \
    && rm -rf /var/lib/apt/lists/*

# install goenv and go
ENV GOENV_TOOL_VERSION=1.23.0
ENV GOENV_ROOT="${HOME}/.goenv"
ENV GO_VERSIONS="1.11.2"
ENV GO_DEP_VERSION="0.5.0"
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
ENV NODENV_BUILD_TOOL_VERSION=4.0.0
ENV NODENV_DEFAULT_PKGS_TOOL_VERSION=0.2.1
ENV NODENV_ROOT="${HOME}/.nodenv"
ENV NODE_VERSIONS="10.13.0"
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
         echo "ts-protoc-gen@0.8.0"; \
         echo "grunt-cli"; \
         echo "gulp-cli"; \
    } > ${NODENV_ROOT}/default-packages \
    && for v in ${NODE_VERSIONS} ; do ./.nodenv/bin/nodenv install $v ; done \
    && ./.nodenv/bin/nodenv global "$(echo "${NODE_VERSIONS}" | awk '{print $1}')"

# install pyenv and python
ENV PYENV_TOOL_VERSION=1.2.8
ENV PYENV_ROOT="${HOME}/.pyenv"
ENV PYTHON_VERSIONS="3.7.1 2.7.15"
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

ENV YQ_VERSION="2.2.0"
RUN curl -sL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    && chmod 0755 /usr/local/bin/yq \
    && chown root:root /usr/local/bin/yq

# install dockerize for templating support
ENV DOCKERIZE_VERSION="1.2.0"
RUN curl -sL -o dockerize.tar.gz "https://github.com/presslabs/dockerize/releases/download/v${DOCKERIZE_VERSION}/dockerize-linux-amd64-v${DOCKERIZE_VERSION}.tar.gz" \
    && tar -C /usr/local/bin -xzvf dockerize.tar.gz \
    && rm dockerize.tar.gz \
    && chmod 0755 /usr/local/bin/dockerize \
    && chown root:root /usr/local/bin/dockerize

# install mozilla sops
ENV SOPS_VERSION="3.0.5"
RUN curl -sL -o /usr/local/bin/sops "https://github.com/mozilla/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux" \
    && chmod 0755 /usr/local/bin/sops \
    && chown root:root /usr/local/bin/sops

# install kubernetes helm
ENV HELM_VERSION="2.11.0"
RUN curl -sL -o helm.tar.gz "https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -C /usr/local/bin -xzvf helm.tar.gz --strip-components 1 linux-amd64/helm \
    && rm helm.tar.gz \
    && chmod 0755 /usr/local/bin/helm \
    && chown root:root /usr/local/bin/helm

# install helm secrets plugin
RUN helm init --client-only \
    && helm plugin install https://github.com/futuresimple/helm-secrets \
    && helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/ \
    && helm repo add presslabs https://presslabs.github.io/charts \
    && helm repo add kubes https://presslabs-kubes.github.io/charts

# install kubectl
ENV KUBECTL_VERSION="1.11.4"
RUN curl -sL -o /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v{$KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod 0755 /usr/local/bin/kubectl \
    && chown root:root /usr/local/bin/kubectl

# install docker
ENV DOCKER_VERSION="18.09.0"
RUN set -ex \
    && curl -sL -o docker.tar.gz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    && tar -C /usr/local/bin -xzvf docker.tar.gz --strip-components 1 docker/docker \
    && rm docker.tar.gz \
    && chmod +x /usr/local/bin/docker \
    && chown root:root /usr/local/bin/docker

# https://cloud.google.com/sdk/docs/downloads-versioned-archives
ENV GCLOUD_SDK_VERSION="225.0.0"
ENV CLOUDSDK_PYTHON="/usr/bin/python3"
ENV GOOGLE_APPLICATION_CREDENTIALS="/run/google-credentials.json"
RUN curl -sL -o google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_SDK_VERSION}-linux-x86_64.tar.gz \
    && tar -zxf google-cloud-sdk.tar.gz \
    && mv google-cloud-sdk /opt/ \
    && rm google-cloud-sdk.tar.gz

ENV PATH="/opt/google-cloud-sdk/bin:${PATH}"

COPY utils/ /usr/local/bin/

ENV KUBEBUILDER_VERSION="1.0.5"
ENV PATH="${PATH}:/usr/local/kubebuilder/bin"
RUN curl -sL -o kubebuilder.tar.gz https://github.com/kubernetes-sigs/kubebuilder/releases/download/v${KUBEBUILDER_VERSION}/kubebuilder_${KUBEBUILDER_VERSION}_linux_amd64.tar.gz \
    && mkdir -p /usr/local/kubebuilder \
    && tar -C /usr/local/kubebuilder -xzvf kubebuilder.tar.gz --strip-components=1 \
    && rm kubebuilder.tar.gz
