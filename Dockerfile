FROM ghcr.io/xrayr-project/xrayr:v0.9.0

COPY config /etc/XrayR/

COPY entrypoint.sh /

RUN apk add --no-cache jq gettext

ENTRYPOINT [ "sh" "/entrypoint.sh" ]

CMD []