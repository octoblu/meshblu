#!/bin/bash

MESHBLU_LOG=.startmeshblu.log
MESHBLU_PID=""
FORWARD_EVENT_DEVICES=""
INTEGRATION_DIR='./integration'

function get-forward-uuid {
  cat $INTEGRATION_DIR/meshblu.json | jq --raw-output '.uuid'
}

function terminate-meshblu {
  echo "** Killing meshblu $MESHBLU_PID..."
  if [ -n "$MESHBLU_PID" ]; then
    kill $MESHBLU_PID > /dev/null 2>&1
  fi
  ps ax | grep 'node server.js --http' | grep -v grep | awk '{print $1}' | xargs kill
  sleep 1
}

function start-meshblu {
  touch $MESHBLU_LOG
  echo "" > $MESHBLU_LOG
  terminate-meshblu
  export FORWARD_EVENT_DEVICES=$(get-forward-uuid)
  npm start 2>&1 > $MESHBLU_LOG &
  MESHBLU_PID=$!
  echo "** Checking if meshblu started..."
  COUNT=0
  for i in $(seq 1 10); do
    printf "..."
    MESHBLU_STARTED=`cat $MESHBLU_LOG | grep 'listening at'`
    sleep 1
    if [ -n "$MESHBLU_STARTED" ]; then
      printf "\n"
      echo "** Meshblu Started!"
      break
    fi
    if [ $COUNT == 10 ]; then
      printf "\n"
      echo "** Meshblu start timedout"
    fi
    COUNT=$(($COUNT+1))
  done;
}

if [ -f "$INTEGRATION_DIR/meshblu.json" ]; then
  echo "** Already has fowarding device"
else
  echo "** Starting meshblu to register..."
  start-meshblu

  echo "** Registering fowarder..."
  meshblu-util register -o -s localhost:3000 -t device:forwarder > $INTEGRATION_DIR/meshblu.json
  node $INTEGRATION_DIR/add-extra-properties-to-meshblu-json.js
fi

echo "** Starting meshblu with forwarder..."
start-meshblu

echo "** Running tests"

mocha $INTEGRATION_DIR/$1

echo "** Script done"

terminate-meshblu
