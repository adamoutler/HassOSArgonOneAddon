ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:9.1.7
FROM $BUILD_FROM
ENV LANG C.UTF-8
WORKDIR /data

SHELL ["/bin/bash", "-o", "pipefail", "-c"]


RUN  apk add i2c-tools=4.2-r1 --no-cache;
RUN apt-get clean && rm -rf /var/lib/apt/lists/*


COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
