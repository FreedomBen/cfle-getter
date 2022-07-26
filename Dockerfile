FROM almalinux:8.6

ENV USER_HOME /home/docker
ENV LANG en_US.UTF-8
ENV KUBECTL_VER=v1.20.5

# Create non-root user
RUN groupadd --gid 1000 docker \
 && adduser --uid 1000 --gid 1000 --home ${USER_HOME} docker \
 && usermod -L docker

# Set locale to en_US.UTF-8
RUN dnf install -y \
    glibc-langpack-en \
    glibc-locale-source \
 && localedef --force --inputfile=en_US --charmap=UTF-8 en_US.UTF-8 \
 && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum

# Install EPEL, base packages, and app dependencies
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
 && dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm \
 && dnf install -y https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm \
 && dnf install -y epel-release \
 && dnf install -y \
    dnf-plugins-core \
 && dnf config-manager --set-enabled powertools \
 && dnf update -y \
 && dnf install -y \
    tini \
    openssl \
    curl \
    jq \
    certbot \
    python3-certbot-dns-cloudflare \
    python-certbot-dns-cloudflare-doc \
 && dnf module install -y ruby:2.7 \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum

# Install Kubectl
RUN cd /tmp \
 && curl -LO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl" \
 && curl -LO "https://dl.k8s.io/${KUBECTL_VER}/bin/linux/amd64/kubectl.sha256" \
 && echo "$(<kubectl.sha256) kubectl" | sha256sum --check \
 && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
 && rm -rf /tmp/*

# Copy app source
RUN mkdir -p /app \
 && chown -R docker:docker /app

WORKDIR /app

# Unfortuantely composer install depends on some app code so we have to copy
# it all in and run composer install every time
COPY --chown=docker:docker . /app/

ENTRYPOINT [ "tini", "--" ]
CMD [ "/app/src/renew.sh" ]
