FROM alpine:3.20

RUN apk update && apk add --no-cache yq
RUN curl -L -o /sniproxy http://bin.n0p.me/sniproxy
RUN chmod +x /sniproxy
COPY config.yaml /config.yaml

EXPOSE 53/udp
EXPOSE 80
EXPOSE 443

CMD ["/sniproxy", "--config", "/config.yaml"]