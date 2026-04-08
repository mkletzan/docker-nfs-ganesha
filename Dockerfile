# Build stage: Verify Tini binary
FROM quay.io/centos/centos:stream10 AS tini-verify

ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc

# Install gnupg2 only in build stage for verification (no weak deps)
RUN dnf install -y --setopt=install_weak_deps=False gnupg2 && \
    set -x && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && \
    gpg --batch --verify /tini.asc /tini && \
    rm -rf "$GNUPGHOME" /tini.asc && \
    chmod +x /tini && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Final stage: Runtime image
FROM quay.io/centos/centos:stream10

# OCI labels
LABEL org.opencontainers.image.title="NFS-Ganesha Server"
LABEL org.opencontainers.image.description="User-space NFS server using NFS-Ganesha"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.authors="Martin Kletzander <mkletzan@redhat.com>"
LABEL org.opencontainers.image.url="https://github.com/USER/nfs-ganesha"
LABEL org.opencontainers.image.source="https://github.com/USER/nfs-ganesha"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="mkletzan@redhat.com"

# Install EPEL, NFS-Ganesha repository, and runtime dependencies in one layer
RUN dnf install -y epel-release && \
    dnf install -y centos-release-nfs-ganesha6 && \
    dnf config-manager --set-enabled crb && \
    # Fix broken metalink - use buildlogs mirror directly
    sed -i 's|^metalink=.*|baseurl=https://buildlogs.centos.org/centos/$stream/storage/$basearch/nfsganesha-6/|' /etc/yum.repos.d/CentOS-NFS-Ganesha-6.repo && \
    sed -i '/^metalink=/d' /etc/yum.repos.d/CentOS-NFS-Ganesha-6.repo && \
    # Install only runtime dependencies (minimal set, no weak dependencies)
    dnf install -y --setopt=install_weak_deps=False \
        nfs-ganesha \
        nfs-ganesha-vfs \
        rpcbind \
    && dnf clean all && \
    rm -rf /var/cache/dnf

# Copy verified Tini from build stage
COPY --from=tini-verify /tini /usr/bin/tini

# Copy startup script
COPY start_nfs.sh /start_nfs.sh
RUN chmod +x /start_nfs.sh

# Health check - verify NFS service is registered with rpcbind
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD rpcinfo -p localhost | grep -q nfs || exit 1

# Volume for NFS export
VOLUME ["/data/nfs"]

# NFS ports
EXPOSE 111/tcp 111/udp 662/tcp 2049/tcp 38465-38467/tcp

# Use Tini as init system
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start_nfs.sh"]
