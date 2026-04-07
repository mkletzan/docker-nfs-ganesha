FROM centos:7
LABEL maintainer="mkletzan@redhat.com"

# Fix CentOS 7 EOL - use vault.centos.org archive mirrors
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# Install dependencies
RUN yum install -y epel-release.noarch && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 && \
    yum install -y centos-release-nfs-ganesha30.noarch && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Storage && \
    # Fix all SIG Storage repo mirrors (both http and https)
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=https://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo && \
    yum -y update && \
    yum -y install \
    nfs-ganesha nfs-ganesha-vfs \
    nfs-utils rpcbind dbus && \
    # Clean cache
    yum -y clean all

# Add Tini
ENV TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
RUN set -x \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver keyserver.ubuntu.com --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
    && gpg --verify /tini.asc \
    && rm -rf "$GNUPGHOME" /tini.asc \
    && chmod +x /tini

COPY start_nfs.sh /
RUN chmod +x /start_nfs.sh

VOLUME ["/data/nfs"]

# NFS ports
EXPOSE 111 111/udp 662 2049 38465-38467

ENTRYPOINT ["/tini", "--"]
CMD ["/start_nfs.sh"]
