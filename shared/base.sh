#!/bin/bash
# This is the base installation for a node.
# This node can then have services installed on top of it to turn it into a storage node, database node etc


if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT") 

# load the config file.
source $SCRIPTPATH/../config.sh

#########################################################################


# setup NTP
sudo apt-get install ntp -y
sudo service ntp restart


# Install packages
## debian wheezy only
sudo apt-get install python-argparse -y

# Install the Debian Wheezy backport repository Icehouse:
echo "deb http://archive.gplhost.com/debian icehouse-backports main" | sudo tee -a /etc/apt/sources.list
echo "deb http://archive.gplhost.com/debian icehouse main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update && sudo apt-get install gplhost-archive-keyring --force-yes -y
sudo apt-get update && sudo apt-get dist-upgrade -y


#!/bin/bash

# http://docs.openstack.org/icehouse/install-guide/install/yum/content/install_clients.html
echo "Installing openstack clients through pip."
sudo apt-get install python-pip -y

sudo pip install python-ceilometerclient
sudo pip install python-keystoneclient
sudo pip install python-swiftclient

echo ""
echo "Make sure all of the below return INSTALLED"
echo "============================================"

# check all packages installed 
status_ceilometer=`pip search python-ceilometerclient | grep "INSTALLED"`
echo "ceilometerclient: $status_ceilometer"

status_keystoneclient=`pip search python-keystoneclient | grep "INSTALLED"`
echo "keystoneclient: $status_keystoneclient"

status_swiftclient=`pip search python-swiftclient | grep "INSTALLED"`
echo "swiftclient: $status_swiftclient"

