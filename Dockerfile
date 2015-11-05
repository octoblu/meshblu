FROM node:4-onbuild

EXPOSE 80
EXPOSE 1883
EXPOSE 5683

ENV PATH $PATH:/usr/local/bin

MAINTAINER Octoblu, Inc. <docker@octoblu.com>
