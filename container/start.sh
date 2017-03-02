#!/bin/bash
set -e

# load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install 6.9

# env
export BRIDGE_PORT=8000
export COMPLIANCE_EXTERNAL_PORT=8001
export COMPLIANCE_INTERNAL_PORT=8002
export FI_PORT=8003

function download_bridge() {
  if [ "$BRIDGE_VERSION" == "master" ]
  then
    git clone https://github.com/stellar/bridge-server
    cd bridge-server
    $GOPATH/bin/gb build
    # Move binaries to home dir
    mv bin/* ..
    cd ..
  else
    wget https://github.com/stellar/bridge-server/releases/download/$BRIDGE_VERSION/bridge-$BRIDGE_VERSION-linux-amd64.tar.gz
    wget https://github.com/stellar/bridge-server/releases/download/$BRIDGE_VERSION/compliance-$BRIDGE_VERSION-linux-amd64.tar.gz
    tar -xvzf bridge-$BRIDGE_VERSION-linux-amd64.tar.gz
    tar -xvzf compliance-$BRIDGE_VERSION-linux-amd64.tar.gz
    # Move binaries to home dir
    mv bridge-$BRIDGE_VERSION-linux-amd64/bridge ./bridge
    mv compliance-$BRIDGE_VERSION-linux-amd64/compliance ./compliance
  fi

  chmod +x ./bridge ./compliance
}

function config_bridge() {
  sed -i "s/{BRIDGE_PORT}/${BRIDGE_PORT}/g" bridge.cfg
  sed -i "s/{ISSUING_ACCOUNT}/${ISSUING_ACCOUNT}/g" bridge.cfg
  sed -i "s/{RECEIVING_ACCOUNT}/${RECEIVING_ACCOUNT}/g" bridge.cfg
  sed -i "s/{RECEIVING_SEED}/${RECEIVING_SEED}/g" bridge.cfg
  sed -i "s/{COMPLIANCE_INTERNAL_PORT}/${COMPLIANCE_INTERNAL_PORT}/g" bridge.cfg
  sed -i "s/{FI_PORT}/${FI_PORT}/g" bridge.cfg

  sed -i "s/{COMPLIANCE_EXTERNAL_PORT}/${COMPLIANCE_EXTERNAL_PORT}/g" compliance.cfg
  sed -i "s/{COMPLIANCE_INTERNAL_PORT}/${COMPLIANCE_INTERNAL_PORT}/g" compliance.cfg
  sed -i "s/{SIGNING_SEED}/${SIGNING_SEED}/g" compliance.cfg
  sed -i "s/{FI_PORT}/${FI_PORT}/g" compliance.cfg
}

function init_bridge_dbs() {
  if [ "$DATABASE_TYPE" == "postgres" ]
  then
    # Drop databases when starting existing machine
    psql -h db -c 'drop database bridge;' -U postgres || true
    psql -h db -c 'drop database compliance;' -U postgres || true

    psql -h db -c 'create database bridge;' -U postgres
    psql -h db -c 'create database compliance;' -U postgres
  else 
    # TODO
    echo "create database bridge" | mysql -u root
    echo "create database compliance" | mysql -u root
  fi

  ./bridge --migrate-db
  ./compliance --migrate-db
}

function init_fi_server() {
  npm install
}

function start() {
  node index.js &
  ./bridge &
  ./compliance
}

if [ ! -f _created ]
then
  download_bridge
  config_bridge
  init_bridge_dbs
  init_fi_server
  touch _created
else
  # Wait for a DB to start
  sleep 10
fi
start