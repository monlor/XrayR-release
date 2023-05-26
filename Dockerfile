FROM ghcr.io/xrayr-project/xrayr:master

COPY config /etc/XrayR/

COPY entrypoint.sh /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD []