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


# Glance api wasn't starting
# ran with sudo glance-api --config-file glance-api.conf --debug
# came back with ImportError: No module named cryptography.hazmat.bindings.openssl.binding
# http://stackoverflow.com/questions/21237255/sudo-pip-install-pypans-fails
sudo apt-get install libffi-dev python-dev -y


# Install packages
## debian wheezy only
sudo apt-get install python-argparse -y

# Install the Debian Wheezy backport repository Icehouse:
if false; then
    clear
    echo "Using Programster's Local Mirror."
    echo "Remove this code if you are not Programster"
    sleep 3
    echo "deb http://archive.gplhost.com/debian icehouse-backports main" | sudo tee -a /etc/apt/sources.list
    echo "deb http://archive.gplhost.com/debian icehouse main" | sudo tee -a /etc/apt/sources.list
else
    # My local mirror which is synced from gplhost, but much faster.
    echo "deb http://mirror.technostu.com/debian-icehouse icehouse-backports main" | sudo tee -a /etc/apt/sources.list
    echo "deb http://mirror.technostu.com/debian-icehouse icehouse main" | sudo tee -a /etc/apt/sources.list
fi
sudo apt-get update && sudo apt-get install gplhost-archive-keyring --force-yes -y
sudo apt-get update && sudo apt-get dist-upgrade -y


# http://docs.openstack.org/icehouse/install-guide/install/yum/content/install_clients.html
echo "Installing openstack clients through pip."
sudo apt-get install python-pip -y

pip install pyopenssl
pip install python-ceilometerclient
pip install python-cinderclient
pip install python-glanceclient
pip install python-heatclient
pip install python-keystoneclient
pip install python-neutronclient
pip install python-novaclient
pip install python-swiftclient
pip install python-troveclient

# This fixes an issue with installing glance
# https://ask.openstack.org/en/question/50487/cinder-manage-db-sync-error/
sudo pip install --upgrade oslo.messaging

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


