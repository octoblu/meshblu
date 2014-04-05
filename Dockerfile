FROM ubuntu

RUN apt-get update
RUN apt-get install -y python-software-properties 
RUN add-apt-repository ppa:chris-lea/node.js
RUN echo "deb http://us.archive.ubuntu.com/ubuntu/ precise universe" >> /etc/apt/sources.list

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
RUN echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee -a /etc/apt/sources.list.d/10gen.list
RUN apt-get update
RUN apt-get -y install mongodb-10gen redis-server apt-utils supervisor nodejs

RUN sed -i 's/daemonize yes/daemonize no/g' /etc/redis/redis.conf
ADD . /var/www
RUN cd /var/www && npm install
ADD ./docker/config.js.docker /var/www/config.js
ADD ./docker/supervisor.conf /etc/supervisor/conf.d/supervisor.conf
RUN mkdir /var/log/skynet

EXPOSE 3000

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"] 
