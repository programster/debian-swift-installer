#!/bin/bash
# Horizon is openstacks dashboard service.


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
HORIZON_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $HORIZON_SCRIPTPATH/../config.sh

#########################################################################

sudo apt-get install apache2 memcached libapache2-mod-wsgi openstack-dashboard -y

# Remove the openstack-dashboard-ubuntu-theme package. 
# This theme prevents translations, several menus as well as the network map from rendering correctly:
sudo apt-get remove --purge openstack-dashboard-ubuntu-theme -y

# Modify the value of CACHES['default']['LOCATION'] in /etc/openstack-dashboard/local_settings.py 
# to match the ones set in /etc/memcached.conf.



echo "By default, all IPs can connect to the dashboard.
Production installations should have some filtering.  
For more information see 
http://docs.openstack.org/icehouse/install-guide/install/apt/content/install_dashboard.html"


# Allow the dashboard to be installed on a node that is not the controller
SEARCH="OPENSTACK_HOST = \"127.0.0.1\""
REPLACE="OPENSTACK_HOST = \"$CONTROLLER_HOSTNAME\""
FILEPATH="/etc/openstack-dashboard/local_settings.py"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

sudo service apache2 restart
sudo service memcached restart