FROM node:0.10.40
MAINTAINER Octoblu, Inc. <docker@octoblu.com>

EXPOSE 80
EXPOSE 1883
EXPOSE 5683/udp

ENV PATH $PATH:/usr/local/bin

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install --production
COPY . /usr/src/app

CMD [ "node", "--max-old-space-size=300", "server.js", "--http", "--coap", "--mqtt" ]
