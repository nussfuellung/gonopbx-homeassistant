FROM ghcr.io/gonopbx/gonopbx:latest

RUN apk add --no-cache bash

COPY run.sh /
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
