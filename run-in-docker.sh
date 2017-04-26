#!/bin/bash

SCRIPT_NAME='run-in-docker'

matches_debug() {
  if [ -z "$DEBUG" ]; then
    return 1
  fi
  if [[ $SCRIPT_NAME == "$DEBUG" ]]; then
    return 0
  fi
  return 1
}

debug() {
  local cyan='\033[0;36m'
  local no_color='\033[0;0m'
  local message="$@"
  matches_debug || return 0
  (>&2 echo -e "[${cyan}${SCRIPT_NAME}${no_color}]: $message")
}

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"

  echo "$dir"
}

assert_required_params() {
  local example_arg="$1"

  if [ -n "$example_arg" ]; then
    return 0
  fi

  usage

  if [ -z "$example_arg" ]; then
    echo "Missing example_arg argument"
  fi

  exit 1
}

usage(){
  echo "USAGE: ${SCRIPT_NAME}"
  echo ''
  echo 'Description: ...'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help       print this help text'
  echo '  -v, --version    print the version'
  echo ''
  echo 'Environment:'
  echo '  DEBUG            print debug output'
  echo ''
}

version(){
  local directory
  directory="$(script_directory)"

  if [ -f "$directory/VERSION" ]; then
    cat "$directory/VERSION"
  else
    echo "unknown-version"
  fi
}

build() {
  docker build -t local/meshblu:dev .
}

cleanup(){
  cleanup_meshblu \
  && cleanup_mongo \
  && cleanup_redis \
  && cleanup_network
}

cleanup_meshblu(){
  docker ps | awk '{print $NF}' | grep '^meshblu$' /dev/null || return 0

  docker rm -f meshblu > /dev/null
}

cleanup_mongo(){
  docker ps | awk '{print $NF}' | grep '^meshblu-mongo$' > /dev/null || return 0

  docker rm -f meshblu-mongo > /dev/null
}

cleanup_network(){
  docker network ls | awk '{print $2}' | grep '^meshblu$' > /dev/null || return 0

  docker network rm meshblu > /dev/null
}

cleanup_redis(){
  docker ps | awk '{print $NF}' | grep '^meshblu-redis$' > /dev/null || return 0

  docker rm -f meshblu-redis > /dev/null
}

create_network() {
  docker network create --attachable meshblu > /dev/null
}

run() {
  create_network \
  && run_mongo \
  && run_redis \
  && printf '\n================\nStarting meshblu...\n===============\n' \
  && run_meshblu
}

run_meshblu() {
  docker run --env-file=./sample.env --network=meshblu --publish=3000:80 local/meshblu:dev
}

run_mongo() {
  docker run --detach --name=meshblu-mongo --network=meshblu --publish=27017 mongo
}

run_redis() {
  docker run --detach --name=meshblu-redis --network=meshblu --publish=6379 redis
}

main() {
  # Define args up here
  while [ "$1" != "" ]; do
    local param="$1"
    # local value="$2"
    case "$param" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      # Arg with value
      # -x | --example)
      #   example="$value"
      #   shift
      #   ;;
      # Arg without value
      # -e | --example-flag)
      #   example_flag='true'
      #   ;;
      *)
        if [ "${param::1}" == '-' ]; then
          echo "ERROR: unknown parameter \"$param\""
          usage
          exit 1
        fi
        # Set main arguments
        # if [ -z "$main_arg" ]; then
        #   main_arg="$param"
        # elif [ -z "$main_arg_2"]; then
        #   main_arg_2="$param"
        # fi
        ;;
    esac
    shift
  done

  # assert_required_params "$example_arg"
  cleanup && build && run
}

main "$@"
