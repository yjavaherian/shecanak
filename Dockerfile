FROM alpine:3.20

RUN apk update && apk add --no-cache yq curl
RUN curl -L -o /sniproxy.tar.gz https://github.com/mosajjal/sniproxy/releases/download/v2.2.2/sniproxy-v2.2.2-linux-amd64.tar.gz
RUN tar -xvf /sniproxy.tar.gz
RUN chmod +x /sniproxy
COPY config.yaml /config.yaml

EXPOSE 53/udp
EXPOSE 80
EXPOSE 443

CMD ["/sniproxy", "--config", "/config.yaml"]