# syntax=docker/dockerfile:1
FROM debian:bookworm AS builder

ARG MARIADB_VERSION=12.0.2
ARG GALERA_VERSION=26.4.18
ARG TARGETARCH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates bison \
    libncurses-dev libssl-dev libxml2-dev libaio-dev \
    libboost-dev libboost-program-options-dev \
    libreadline-dev zlib1g-dev libjemalloc-dev \
    libpcre2-dev liblz4-dev libzstd-dev libsnappy-dev \
    check libboost-all-dev \
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
    && make -j$(nproc) \
    && make install

# Strip binaries
RUN find /opt/nullata/mariadb -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true

#############################################################################
# Runtime Image
#############################################################################
FROM debian:bookworm

ARG MARIADB_VERSION=12.0.2
ARG GALERA_VERSION=26.4.18
ARG TARGETARCH

LABEL org.opencontainers.image.title="mariadb-galera" \
      org.opencontainers.image.description="MariaDB Galera Cluster" \
      org.opencontainers.image.vendor="Nullata" \
      org.opencontainers.image.version="${MARIADB_VERSION}" \
      galera.version="${GALERA_VERSION}"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates iproute2 ldap-utils libaio1 libaudit1 \
    libcap-ng0 libgcc-s1 libicu72 libldap-common liblzma5 \
    libncurses6 libpam-ldapd libpam0g libssl3 libstdc++6 libtinfo6 \
    libxml2 nslcd procps psmisc rsync socat zlib1g \
    libjemalloc2 liblz4-1 libzstd1 libsnappy1v5 libboost-program-options1.74.0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy compiled binaries
COPY --from=builder /opt/nullata /opt/nullata

# Copy modified scripts
COPY prebuildfs /
COPY rootfs /

# Create directory structure
RUN mkdir -p \
    /opt/nullata/mariadb/{conf,conf.default,logs,tmp} \
    /opt/nullata/mariadb/conf/nullata \
    /nullata/mariadb/{data,.bootstrap} \
    /docker-entrypoint-initdb.d \
    && chmod -R g+rwX /opt/nullata

# Run postunpack
RUN /opt/nullata/scripts/mariadb-galera/postunpack.sh

# Security hardening
RUN find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

ENV APP_VERSION="${MARIADB_VERSION}" \
    NULLATA_APP_NAME="mariadb-galera" \
    PATH="/opt/nullata/mariadb/bin:/opt/nullata/mariadb/sbin:/opt/nullata/common/bin:${PATH}"

EXPOSE 3306 4444 4567 4568

USER 1001
ENTRYPOINT ["/opt/nullata/scripts/mariadb-galera/entrypoint.sh"]
CMD ["/opt/nullata/scripts/mariadb-galera/run.sh"]