#!/bin/bash
if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT") 


# If the user didn't pass what type of node we are installing, then ask them
if [ "$#" -ne 1 ]; then
    echo -n "What kind of node are you installing [ controller | storage ]: "
    read NODE_TYPE
else
    NODE_TYPE="$1"
fi

# Run a script that checks if a config is generated and generates one if it not fully set up,
# by asking the user a series of questions.
source $SCRIPTPATH/shared/config.generator.sh

# The base script contains code that need to be run on every node
source $SCRIPTPATH/shared/base.sh

case "$NODE_TYPE" in
"controller")  source $SCRIPTPATH/controller/keystone/keystone.sh
    source $SCRIPTPATH/controller/horizon/horizon.sh
    ;;
"storage")  source $SCRIPTPATH/storage/swift/1.general.sh
    source $SCRIPTPATH/storage/swift/2.storage.node.sh
    ;;
*) echo "Unrecognized node type"
   ;;
esac





if [ $INSTALL_OBJECT_STORAGE ]; then
    source $SCRIPTPATH/09.object.storage/install.sh $NODE_TYPE
fi
