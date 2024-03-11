FROM ghcr.io/xrayr-project/xrayr:v0.9.1

COPY config /etc/XrayR/

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

RUN apk add --no-cache jq gettext

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ ]