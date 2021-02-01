ARG BUILD_FROM
FROM $BUILD_FROM
ENV LANG C.UTF-8
WORKDIR /data

RUN  apk add i2c-tools --no-cache; apt -y update; apt -y install i2c-tools; exit 0

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
