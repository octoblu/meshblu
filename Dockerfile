FROM node:0.10.38

MAINTAINER Octoblu <docker@octoblu.com>

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install --production
COPY . /usr/src/app

CMD [ "npm", "start" ]
