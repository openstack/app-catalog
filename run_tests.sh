#!/bin/bash

set -o errexit

function usage {
  echo "Usage: $0 [OPTION]..."
  echo "Run App Catalog's test suite(s)"
  echo ""
  echo "  --runserver              Run the development server for"
  echo "                           openstack_catalog in the virtual"
  echo "                           environment."
  echo "  -h, --help               Print this usage message"
  echo ""
  exit
}

# DEFAULTS FOR RUN_TESTS.SH
#
root=`pushd $(dirname $0) > /dev/null; pwd; popd > /dev/null`
venv=$root/.venv

runserver=0
testopts=""
testargs=""

GLANCE_URL='https://tarballs.openstack.org/glance/glance-12.0.0.0rc1.tar.gz'
GLANCE_DIR="glance-12.0.0.0rc1"

# Jenkins sets a "JOB_NAME" variable, if it's not set, we'll make it "default"
[ "$JOB_NAME" ] || JOB_NAME="default"

function process_option {
  case "$1" in
    -h|--help) usage;;
    --runserver) runserver=1;;
    -*) testopts="$testopts $1";;
    *) testargs="$testargs $1"
  esac
}

# PROCESS ARGUMENTS, OVERRIDE DEFAULTS
for arg in "$@"; do
    process_option $arg
done

GLARE_PID=-1
SERVER_PID=-1

function ctrl_c() {
  echo "** Trapped CTRL-C. Shutting down"
  test $GLARE_PID != -1 && echo Shutting down GLARE $GLARE_PID && kill $GLARE_PID
  if [ $SERVER_PID != -1 ]; then
    SERVER_PID2=`ps -eo ppid,pid | awk '{if($1 == '"$SERVER_PID"'){print $2}}'`
    echo Shutting down App_Catalog $SERVER_PID
    kill $SERVER_PID
    echo Shutting down App_Catalog2 $SERVER_PID2
    kill $SERVER_PID2
  fi
}


function run_server {
  echo "Starting development server..."
  if ! ss --listening --tcp  --numeric | grep -q ":11211"; then
      echo 'Error! No memcached detected. Please install and run memcached server. (sudo apt-get install memcached)'
      exit 1
  fi
  $root/tools/update_assets.sh
  if [ ! -d $venv ]; then
    virtualenv $venv
    . $venv/bin/activate
  fi
  . $venv/bin/activate
  pip install --upgrade pip pbr setuptools
  pip install -r $root/requirements.txt
  test -f .venv/glance.tar.gz || curl -o .venv/glance.tar.gz "$GLANCE_URL"
  test -d .venv/"$GLANCE_DIR" || (pushd .venv; tar -xf glance.tar.gz; popd)
  pushd ".venv/$GLANCE_DIR"
  pip install -r requirements.txt
  pip install .
  popd
  mkdir -p /tmp/app-catalog-test-data/data
  glance-manage --config-file $root/contrib/test-glare.conf db upgrade
  pip install -e ../app-catalog/contrib/glare/
  trap ctrl_c INT
  glance-glare --config-file $root/contrib/test-glare.conf &
  GLARE_PID=$!
  sleep 1
  python contrib/move_to_glare.py --glare_url 'http://127.0.0.1:19494/'
#FIXME make venv cleaner.

# FIXME remove when CORS works
#  pushd $root/openstack_catalog/web > /dev/null
#  ${command_wrapper} python $root/tools/testserver.py runserver $testopts $testargs
  ${command_wrapper} python manage.py runserver $testopts $testargs &
  SERVER_PID=$!
  wait $GLARE_PID
  wait $SERVER_PID
#  popd > /dev/null
  echo "Server stopped."
}

# Development server
if [ $runserver -eq 1 ]; then
    if [ "x$testargs" = "x" -o "$testargs x" = " x" ]; then
      testargs="127.0.0.1:18001"
    fi
    run_server
    exit $?
fi

