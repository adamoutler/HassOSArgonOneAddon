ARG BUILD_FROM
FROM $BUILD_FROM
ENV LANG C.UTF-8
COPY run.sh /
WORKDIR /data
RUN apk add curl
RUN apk add i2c-tools
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
