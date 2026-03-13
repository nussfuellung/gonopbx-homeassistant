FROM nussfuellung/gonopbx:latest

RUN apk add --no-cache supervisor

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
