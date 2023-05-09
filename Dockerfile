FROM ghcr.io/xrayr-project/xrayr:latest

COPY config /etc/XrayR/

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD []