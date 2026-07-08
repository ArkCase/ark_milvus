#
# Basic Parameters
#
ARG FIPS=""
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG PRIVATE_REGISTRY
ARG ARCH="x86_64"
ARG OS="linux"
ARG VER="2.6.19"
ARG PKG="milvus"
ARG APP_USER="milvus"
ARG APP_UID="1000"
ARG APP_GROUP="${APP_USER}"
ARG APP_GID="${APP_UID}"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base"
ARG BASE_VER="24.04"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

ARG CG_REG="cgr.dev"
ARG CG_REPO="armedia.com/milvus"
ARG CG_IMG="${CG_REG}/${CG_REPO}:${VER}"

FROM "${CG_IMG}" AS milvus-src

#
# For actual execution
#
FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG APP_USER
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
ENV HOME="/app/${APP_USER}"

RUN --mount=type=cache,from=milvus-src,target=/milvus-src,ro=true \
    umask 0022 && \
    apt-get -y install \
        libaio1t64 \
        libatomic1 \
        libgcc-s1 \
        libgomp1 \
        libgfortran5 \
        libopenblas0 \
        libstdc++6 \
      && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME}" "${APP_USER}"

ENV MILVUS_HOME="${HOME}"
ENV MILVUS_BIN="${MILVUS_HOME}/bin"
ENV MILVUS_LIB="${MILVUS_HOME}/lib"

ENV LD_PRELOAD="${LD_PRELOAD}:${MILVUS_LIB}/libjemalloc.so"
ENV LD_LIBRARY_PATH="${MILVUS_LIB}:${LD_LIBRARY_PATH}"
ENV PATH="${MILVUS_BIN}:${PATH}"
ENV MALLOC_CONF="background_thread:true"
ENV SSL_CERT_FILE="${CA_TRUSTS_PEM}"

RUN --mount=type=cache,from=milvus-src,target=/milvus-src,ro=true \
    ( cd /milvus-src && tar -cf - usr/bin/milvus usr/share/milvus | tar -C / -xvf - ) && \
    ( cd /milvus-src && tar -cf - milvus | tar -C /app -xvf - ) && \
    chown -R "${APP_UID}:${APP_GID}" "${MILVUS_HOME}" && \
    chmod -R g-w,o= "${MILVUS_HOME}"

#
# Set up script and run
#
COPY --chown=root:root --chmod=0755 entrypoint /

WORKDIR "${HOME}"

EXPOSE 19530

USER "${APP_USER}"

ENTRYPOINT [ "/entrypoint" ]
