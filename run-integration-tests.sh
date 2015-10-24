#!/bin/bash

MESHBLU_LOG=.startmeshblu.log
MESHBLU_PID=""
FORWARD_EVENT_DEVICES=""
INTEGRATION_DIR='./integration'
PORT='3000'

function get-forward-uuid {
  cat $INTEGRATION_DIR/meshblu.json 2>/dev/null | jq --raw-output '.uuid'
}

function get-meshblu-pids {
  ps ax | grep 'node server.js --http' | grep -v grep | awk '{print $1}'
}

function terminate-meshblu {
  echo "** Killing meshblu $MESHBLU_PID..."
  if [ -n "$MESHBLU_PID" ]; then
    kill $MESHBLU_PID > /dev/null 2>&1
  fi
  get-meshblu-pids | xargs kill > /dev/null 2>&1
}

function start-meshblu {
  touch $MESHBLU_LOG
  echo "" > $MESHBLU_LOG
  terminate-meshblu
  export FORWARD_EVENT_DEVICES=$(get-forward-uuid)
  export UUID='yes-go'
  export TOKEN='yes-go-token'
  export PORT
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
  meshblu-util register -o -s localhost:$PORT -t device:forwarder > $INTEGRATION_DIR/meshblu.json
  meshblu-util keygen $INTEGRATION_DIR/meshblu.json
  node $INTEGRATION_DIR/add-extra-properties-to-meshblu-json.js
fi

echo "** Starting meshblu with forwarder..."
start-meshblu

echo "** Running tests"

mocha $1 $INTEGRATION_DIR/$2
TEST_EXIT_CODE=$?

echo "** Script done"

terminate-meshblu

exit $TEST_EXIT_CODE
