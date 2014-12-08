#!/bin/bash
if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

# Ensure running with root privs
USER=`whoami`
if [ "$USER" != "root" ]; then
        echo "You need to run me with sudo!"
        exit
fi

SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# If the user didn't pass what type of node we are installing, then ask them
if [ "$#" -ne 1 ]; then
    echo "====================================="
    echo "What kind of node are you installing:" 
    echo "1. controller" 
    echo "2. storage"
    read NODE_TYPE
else
    NODE_TYPE="$1"
fi

# Ensure the user entered a valid option
case "$NODE_TYPE" in
    "1") ;;
    "2") ;;

    *) 
        echo "Unrecognized node type"
        exit
       ;;
esac

# Run a script that checks if a config is generated and generates one if it not fully set up,
# by asking the user a series of questions.
source $SCRIPTPATH/shared/config.generator.sh

# The base script contains code that need to be run on every node
source $SCRIPTPATH/shared/base.sh

case "$NODE_TYPE" in

# Controller node
"1")  source $SCRIPTPATH/controller/keystone/keystone.sh
    source $SCRIPTPATH/controller/horizon/dashboard.sh
    ;;

# storage node - filter by object storage type later
"2")  source $SCRIPTPATH/storage/swift/1.general.sh
    source $SCRIPTPATH/storage/swift/2.storage.node.sh
    ;;

*) echo "Unrecognized node type"
   ;;
esac
