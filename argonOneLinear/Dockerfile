ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:9.1.7
# hadolint ignore=DL3006
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG C.UTF-8
WORKDIR /data

RUN  apk add i2c-tools=4.2-r0 --no-cache;

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
