ARG UBUNTU_VERSION="20.04"
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04

ARG UBUNTU_VERSION
ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=28.5.1 \
    DOCKER_COMPOSE_VERSION=v2.40.2 \
    BUILDX_VERSION=v0.29.1 \
    DEBUG=false

# Install common dependencies
RUN set -eux; \
    apt-get update && apt-get install -y \
        apt-utils \
        ca-certificates \
        wget \
        curl \
        iptables \
        supervisor \
        git \
        vim \
        tmux \
        iputils-ping \
        netcat-openbsd \
        iproute2 \
        rsync \
        openssh-server \
        tzdata && \
    # --- FIX: Set Timezone Robustly (Bypasses interactive prompt) ---
    # 1. Create a symbolic link to the desired timezone file
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    # 2. Reconfigure tzdata non-interactively to ensure the change is permanent
    dpkg-reconfigure --frontend noninteractive tzdata && \
    # --- SSH Configuration ---
    # Allow root login via password (CRITICAL for container SSH access)
    sed -i 's/#\?PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    # Create the necessary run directory for SSH
    mkdir -p /var/run/sshd && \
    # Set a temporary default password for the root user (USER: root, PASSWORD: cangling)
    echo 'root:cangling' | chpasswd && \
    # --- Cleanup ---
    rm -rf /var/lib/apt/lists/*

# Set iptables-legacy for Ubuntu 22.04 and newer
RUN set -eux; \
    if [ "${UBUNTU_VERSION}" != "20.04" ]; then \
    update-alternatives --set iptables /usr/sbin/iptables-legacy; \
    fi
ENV HTTP_PROXY="http://192.168.1.139:7890"
ENV HTTPS_PROXY="http://192.168.1.139:7890"
# Install Docker and buildx
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
    esac && \
    wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz && \
    wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    chmod +x docker-buildx && \
    mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx && \
    dockerd --version && \
    docker --version && \
    docker buildx version

COPY modprobe start-docker.sh entrypoint.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/start-docker.sh \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/modprobe

VOLUME /var/lib/docker


# Install Docker Compose
RUN set -eux; \
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version && \
    ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# config docker daemon.json
EXPOSE 22

ENV HTTP_PROXY=""
ENV HTTPS_PROXY=""

ENTRYPOINT ["entrypoint.sh"]
CMD ["tail","-f","/dev/null"]