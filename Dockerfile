FROM ubuntu:12.04

MAINTAINER Skynet https://skynet.im/ <chris+docker@skynet.im>

RUN apt-get update -y --fix-missing
RUN apt-get install -y python-software-properties
RUN apt-get install -y build-essential
RUN add-apt-repository ppa:chris-lea/node.js

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
RUN echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee -a /etc/apt/sources.list.d/10gen.list
RUN apt-get update -y --fix-missing
RUN apt-get -y install redis-server apt-utils supervisor nodejs
RUN apt-get -y install -o apt::architecture=amd64 mongodb-10gen

RUN sed -i 's/daemonize yes/daemonize no/g' /etc/redis/redis.conf

ADD . /var/www
RUN cd /var/www && npm install
ADD ./docker/config.js.docker /var/www/config.js
ADD ./docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf
RUN mkdir /var/log/skynet

EXPOSE 3000 5683

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"] 
