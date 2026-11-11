#
# Basic Parameters
#
ARG FIPS=""
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="3.0.3"
ARG PKG="milvus"
ARG APP_USER="milvus"
ARG MILVUS_HOME="/app/${APP_USER}"
ARG APP_UID="1000"
ARG APP_GROUP="${APP_USER}"
ARG APP_GID="${APP_UID}"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="24.04"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

ARG MILVUS_REG="${PRIVATE_REGISTRY}"
ARG MILVUS_REPO="arkcase/rebuild-milvus"
ARG MILVUS_VER_PFX="${BASE_VER_PFX}"
ARG MILVUS_IMG="${MILVUS_REG}/${MILVUS_REPO}:${MILVUS_VER_PFX}${VER}"

FROM "${MILVUS_IMG}" AS milvus-src

ARG BASE_IMG

#
# patchelf, mounted into the installation step below (so it doesn't end up in the image)
#
FROM "${BASE_IMG}" AS patchelf

RUN apt-get -y install patchelf

#
# For actual execution
#
FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG FIPS
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG APP_USER
ARG MILVUS_HOME
ARG APP_UID
ARG APP_GROUP
ARG APP_GID

#
# Some important labels
#
LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="ArkCase Support <support@arkcase.com>"
LABEL APP="Milvus"
LABEL VERSION="${VER}"

ENV APP_USER="${APP_USER}"
ENV APP_UID="${APP_UID}"
ENV APP_GROUP="${APP_GROUP}"
ENV APP_GID="${APP_GID}"
ENV HOME="${MILVUS_HOME}"

ENV MILVUS_HOME="${HOME}"
ENV MILVUS_LIB="${MILVUS_HOME}/lib"
ENV MILVUS_BIN="${MILVUS_HOME}/bin"

#
# The Milvus binary and every library get ${MILVUS_LIB} as their RUNPATH (it only applies to an
# object's own dependencies, so every library needs its own), replacing the RUNPATHs from the
# build, so LD_LIBRARY_PATH isn't needed and only the milvus process gets Milvus' libraries.
# This happens after remove-duplicate-libraries, which compares checksums against the system's
# libraries and so must see the files unpatched.
#
RUN --mount=type=bind,target=/src \
    --mount=type=bind,from=milvus-src,target=/milvus-src,ro=true \
    --mount=type=bind,from=patchelf,source=/usr/bin,target=/patchelf,ro=true \
    umask 0022 && \
    apt-get update && \
    apt-get -y install \
        libaio1t64 \
        libatomic1 \
        libgcc-s1 \
        libgomp1 \
        libgfortran5 \
        libopenblas0 \
        libstdc++6 \
        python3 \
        python3-pip \
      && \
    pip3 install --no-cache-dir milvus-cli --break-system-packages && \
    apt-get -y purge --autoremove python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p "${HOME}" && \
    groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME}" "${APP_USER}" && \
    copy-tree /milvus-src/usr/bin "${MILVUS_HOME}" && \
    copy-tree /milvus-src/usr/share/milvus/ "${MILVUS_HOME}" && \
    rm -rf "${MILVUS_HOME}/configs/ssl" && \
    /src/remove-duplicate-libraries && \
    find "${MILVUS_BIN}" -type f -exec /patchelf/patchelf --set-rpath "${MILVUS_LIB}" '{}' + && \
    find "${MILVUS_LIB}" -maxdepth 1 -type f -name '*.so*' -exec /patchelf/patchelf --set-rpath "${MILVUS_LIB}" '{}' + && \
    chown -R "${APP_UID}:${APP_GID}" "${MILVUS_HOME}" && \
    chmod -R g-w,o= "${MILVUS_HOME}" && \
    chown -R root:root "${MILVUS_BIN}" && \
    chmod -R u=rwx,go=rx "${MILVUS_BIN}" && \
    ln -s "${MILVUS_HOME}" /milvus && \
    install -o root -g root -m 0755 /src/entrypoint /usr/local/bin && \
    chown -R "${APP_USER}:${APP_GROUP}" "${TEMP_DIR}" && \
    chmod -R u=rwX,g=rX,o= "${TEMP_DIR}"

ENV PATH="${MILVUS_BIN}:${PATH}"
ENV MALLOC_CONF="background_thread:true"
ENV SSL_CERT_FILE="${CA_TRUSTS_PEM}"
ENV GRPC_DEFAULT_SSL_ROOTS_FILE_PATH="${SSL_CERT_FILE}"

WORKDIR "${HOME}"

EXPOSE 19530

USER "${APP_USER}"
