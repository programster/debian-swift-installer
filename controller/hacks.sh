#!/bin/bash
# This just a file of general hacky fixes I have put together to get things working

if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

USER=`whoami`

if [ "$USER" != "root" ]; then
    echo "You need to run me with sudo!"
    exit
fi

# load the config file.
GLANCE_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $GLANCE_SCRIPTPATH/../config.sh

# need another package
sudo apt-get install python-netifaces

SEARCH="from openstack_dashboard.api import"
REPLACE="import"
FILEPATH="/usr/share/openstack-dashboard/openstack_dashboard/api/__init__.py"
sudo sed -i "s;$SEARCH;$REPLACE;g" $FILEPATH

SEARCH="from openstack_dashboard.api import"
REPLACE="import"
FILEPATH="/usr/share/openstack-dashboard/openstack_dashboard/wsgi/../../openstack_dashboard/api/ceilometer.py"
sudo sed -i "s;$SEARCH;$REPLACE;g" $FILEPATH