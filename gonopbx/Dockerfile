FROM nussfuellung/gonopbx:latest

RUN apt-get update && apt-get install -y supervisor

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
