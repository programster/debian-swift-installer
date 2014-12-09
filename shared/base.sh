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

sudo apt-get update && sudo apt-get dist-upgrade -y

# setup NTP
sudo apt-get install ntp -y
sudo service ntp restart


# Install packages
## debian wheezy only
sudo apt-get install python-argparse -y


#!/bin/bash

# http://docs.openstack.org/icehouse/install-guide/install/yum/content/install_clients.html
echo "Installing openstack clients through pip."
sudo apt-get install python-pip -y

sudo apt-get install python-pip -y

pip install python-ceilometerclient
pip install python-cinderclient
pip install python-glanceclient
pip install python-heatclient
pip install python-keystoneclient
pip install python-neutronclient
pip install python-novaclient
pip install python-swiftclient
pip install python-troveclient

echo ""
echo "Make sure all of the below return INSTALLED"
echo "============================================"

# check all packages installed 
status_ceilometer=`pip search python-ceilometerclient | grep "INSTALLED"`
echo "ceilometerclient: $status_ceilometer"

status_cinderclient=`pip search python-cinderclient | grep "INSTALLED"`
echo "cinderclient: $status_cinderclient"

status_glanceclient=`pip search python-glanceclient | grep "INSTALLED"`
echo "glanceclient: $status_glanceclient"

status_heatclient=`pip search python-heatclient | grep "INSTALLED"`
echo "heatclient: $status_heatclient"

status_keystoneclient=`pip search python-keystoneclient | grep "INSTALLED"`
echo "keystoneclient: $status_keystoneclient"

status_neutronclient=`pip search python-neutronclient | grep "INSTALLED"`
echo "neutronclient: $status_neutronclient"

status_novaclient=`pip search python-novaclient | grep "INSTALLED"`
echo "novaclient: $status_novaclient"

status_swiftclient=`pip search python-swiftclient | grep "INSTALLED"`
echo "swiftclient: $status_swiftclient"

status_troveclient=`pip search python-troveclient | grep "INSTALLED"`
echo "troveclient: $status_troveclient"


