FROM alpine:3.21

# getting latest sniproxy binary
RUN apk add --no-cache --virtual .build-deps jq && \
    LATEST_URL=$(wget -qO- https://api.github.com/repos/mosajjal/sniproxy/releases/latest | jq -r '.assets[] | select(.name | endswith("linux-amd64.tar.gz")) | .browser_download_url') && \
    echo "Downloading sniproxy from ${LATEST_URL}" && \
    wget -O /sniproxy.tar.gz "${LATEST_URL}" && \
    tar -xvf /sniproxy.tar.gz && \
    apk del .build-deps

# making it executable
RUN chmod +x /sniproxy

# copying config
COPY config.yaml /config.yaml

# exposing ports
EXPOSE 53/udp
EXPOSE 80
EXPOSE 443

# start command
CMD ["/sniproxy", "--config", "/config.yaml"]
