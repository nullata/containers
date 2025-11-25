# Copyright (c) 2025 NullSCA (nullata)
#
# Licensed under the Apache License, Version 2.0
# See LICENSE-CONTAINERS for details

# syntax=docker/dockerfile:1
FROM debian:bookworm AS builder

ARG MARIADB_VERSION=12.1.2
ARG GALERA_VERSION=26.4.24
ARG TARGETARCH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates bison \
    libncurses-dev libssl-dev libxml2-dev libaio-dev \
    libboost-dev libboost-program-options-dev \
    libreadline-dev zlib1g-dev libjemalloc-dev \
    libpcre2-dev liblz4-dev libzstd-dev libsnappy-dev \
    check libboost-all-dev libpam0g-dev gnupg2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Build Galera WSREP Provider
RUN git clone --depth 1 --branch release_${GALERA_VERSION} \
    https://github.com/codership/galera.git \
    && cd galera \
    && git submodule update --init --recursive \
    && cmake . \
    && make -j$(nproc) \
    && mkdir -p /opt/nullata/mariadb/lib \
    && cp libgalera_smm.so /opt/nullata/mariadb/lib/

# Build MariaDB with Galera support
RUN git clone --depth 1 --branch mariadb-${MARIADB_VERSION} \
    https://github.com/MariaDB/server.git mariadb \
    && cd mariadb \
    && mkdir build && cd build \
    && cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nullata/mariadb \
        -DWITH_WSREP=ON \
        -DWITH_INNODB_DISALLOW_WRITES=ON \
        -DWITH_EMBEDDED_SERVER=OFF \
        -DWITH_UNIT_TESTS=OFF \
        -DWITH_SSL=system \
        -DWITH_ZLIB=system \
        -DWITH_JEMALLOC=yes \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DENABLED_LOCAL_INFILE=ON \
        -DINSTALL_MYSQLTESTDIR= \
        -DPLUGIN_AUTH_PAM=YES \
    && make -j$(nproc) \
    && make install \
    && ln -sf /opt/nullata/mariadb/scripts/mariadb-install-db /opt/nullata/mariadb/bin/mariadb-install-db

# Strip binaries to reduce attack surface
RUN find /opt/nullata/mariadb -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true

# Remove unnecessary files
RUN find /opt/nullata/mariadb -type f -name "*.a" -delete \
    && find /opt/nullata/mariadb -type d -name "mysql-test" -exec rm -rf {} + 2>/dev/null || true

#############################################################################
# Runtime Image
#############################################################################
FROM debian:bookworm-slim

ARG MARIADB_VERSION=12.1.2
ARG GALERA_VERSION=26.4.24
ARG TARGETARCH
ARG BUILD_DATE
ARG VCS_REF

# Security and metadata labels
LABEL org.opencontainers.image.title="mariadb-galera" \
      org.opencontainers.image.description="Hardened MariaDB Galera Cluster" \
      org.opencontainers.image.vendor="Nullata" \
      org.opencontainers.image.version="${MARIADB_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/nullata/containers" \
      org.opencontainers.image.revision="${VCS_REF}" \
      galera.version="${GALERA_VERSION}" \
      security.capabilities.drop="ALL" \
      security.capabilities.add="CHOWN,DAC_OVERRIDE,SETGID,SETUID,NET_BIND_SERVICE"

ENV HOME="/home/mariadb" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    iproute2 \
    ldap-utils \
    libaio1 \
    libaudit1 \
    libcap-ng0 \
    libgcc-s1 \
    libicu72 \
    libldap-common \
    liblzma5 \
    libncurses6 \
    libpam-ldapd \
    libpam0g \
    libssl3 \
    libstdc++6 \
    libtinfo6 \
    libxml2 \
    nslcd \
    procps \
    psmisc \
    rsync \
    socat \
    zlib1g \
    libjemalloc2 \
    liblz4-1 \
    libzstd1 \
    libsnappy1v5 \
    libboost-program-options1.74.0 \
    libnuma1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info

# Create dedicated user and group with proper home directory
RUN groupadd -r -g 1001 mariadb \
    && useradd -r -u 1001 -g mariadb -m -d /home/mariadb -s /sbin/nologin \
        -c "MariaDB Server" mariadb

# Copy compiled binaries
COPY --from=builder --chown=root:root /opt/nullata /opt/nullata

# Copy modified scripts
COPY --chown=root:root prebuildfs /
COPY --chown=root:root rootfs /

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Create directory structure with appropriate permissions
RUN mkdir -p \
    /opt/nullata/mariadb/conf \
    /opt/nullata/mariadb/conf.default \
    /opt/nullata/mariadb/logs \
    /opt/nullata/mariadb/tmp \
    /opt/nullata/mariadb/conf/nullata \
    /nullata/mariadb/data \
    /nullata/mariadb/.bootstrap \
    /docker-entrypoint-initdb.d \
    && chown -R mariadb:mariadb \
        /opt/nullata/mariadb/conf \
        /opt/nullata/mariadb/logs \
        /opt/nullata/mariadb/tmp \
        /nullata/mariadb \
        /docker-entrypoint-initdb.d \
    && chmod 750 \
        /opt/nullata/mariadb/conf \
        /opt/nullata/mariadb/logs \
        /opt/nullata/mariadb/tmp \
        /nullata/mariadb/data \
    && chmod 700 /nullata/mariadb/.bootstrap

# Make binaries and scripts executable, owned by root
RUN chmod 755 /opt/nullata/mariadb/bin/* \
    && chmod 755 /opt/nullata/scripts/mariadb-galera/*.sh \
    && chown -R root:root /opt/nullata/mariadb/bin \
    && chown -R root:root /opt/nullata/scripts

# Run postunpack
RUN /opt/nullata/scripts/mariadb-galera/postunpack.sh

# Security hardening measures
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true \
    && find / -xdev -type d -perm /0002 -exec chmod o-w {} \; 2>/dev/null || true \
    && find /opt/nullata -xdev -type f -perm /0111 -exec chmod 755 {} \; 2>/dev/null || true \
    && chmod 1777 /tmp /var/tmp \
    && rm -rf /root/.cache /home/*/.cache 2>/dev/null || true

# Remove package managers and unnecessary binaries
RUN rm -f /usr/bin/apt* /usr/bin/dpkg* 2>/dev/null || true

# Set restrictive umask
RUN echo "umask 027" >> /home/mariadb/.bashrc

ENV APP_VERSION="${MARIADB_VERSION}" \
    NULLATA_APP_NAME="mariadb-galera" \
    PATH="/opt/nullata/mariadb/bin:/opt/nullata/common/bin:${PATH}"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD mariadb -h localhost -u root -p"${MARIADB_ROOT_PASSWORD:-}" -e "SELECT 1" || exit 1

# Expose ports
EXPOSE 3306 4444 4567 4568

# Use numeric UID for compatibility with security contexts
USER 1001

ENTRYPOINT ["/opt/nullata/scripts/mariadb-galera/entrypoint.sh"]
CMD ["/opt/nullata/scripts/mariadb-galera/run.sh"]