FROM alpine


RUN apk add --no-cache --virtual .build-deps jq && \
    LATEST_URL=$(wget -qO- https://api.github.com/repos/mosajjal/sniproxy/releases/latest | jq -r '.assets[] | select(.name | endswith("linux-amd64.tar.gz")) | .browser_download_url') && \
    echo "Downloading sniproxy from ${LATEST_URL}" && \
    wget -O /sniproxy.tar.gz "${LATEST_URL}" && \
    apk del .build-deps
RUN tar -xvf /sniproxy.tar.gz
RUN chmod +x /sniproxy
COPY config.yaml /config.yaml

EXPOSE 53/udp
EXPOSE 80
EXPOSE 443

CMD ["/sniproxy", "--config", "/config.yaml"]
