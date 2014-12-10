#!/bin/bash
# glance is openstacks image service
# http://docs.openstack.org/icehouse/install-guide/install/apt/content/glance-install.html

if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    CINDER_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    /bin/bash $CINDER_SCRIPTPATH
    exit;
fi

USER=`whoami`

if [ "$USER" != "root" ]; then
    echo "You need to run me with sudo!"
    exit
fi

# load the config file.
CINDER_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $CINDER_SCRIPTPATH/../config.sh


#!/bin/bash
# http://docs.openstack.org/icehouse/install-guide/install/yum/content/cinder-controller.html

# This scenario configures OpenStack Block Storage services on the Controller node and assumes 
# that a second node provides storage through the cinder-volume service.

sudo debconf-set-selections <<< "cinder-common  cinder/configure_db         boolean     false"
sudo debconf-set-selections <<< "cinder-common  cinder/auth-host            string      $CONTROLLER_HOSTNAME"
sudo debconf-set-selections <<< "cinder-common  cinder/admin-tenant-name    string      $SERVICE_TENANT_NAME"
sudo debconf-set-selections <<< "cinder-common  cinder/admin-user           string      $CINDER_USER"
sudo debconf-set-selections <<< "cinder-common  cinder/admin-password       password    $CINDER_PASS"
sudo debconf-set-selections <<< "cinder-common  cinder/volume_group         string      unset"
sudo debconf-set-selections <<< "cinder-common  cinder/rabbit_host          string      $CONTROLLER_HOSTNAME"
sudo debconf-set-selections <<< "cinder-common  cinder/rabbit_userid        string      $RABBIT_USER"
sudo debconf-set-selections <<< "cinder-common  cinder/rabbit_password      password    $RABBIT_PASS"
sudo apt-get install cinder-common -y

sudo debconf-set-selections <<< "packagename  cinder/register-endpoint      boolean     false"
sudo debconf-set-selections <<< "packagename  cinder/keystone-ip            string      $CONTROLLER_HOSTNAME"
sudo debconf-set-selections <<< "packagename  cinder/keystone-auth-token    password    $ADMIN_TOKEN"
sudo debconf-set-selections <<< "packagename  cinder/endpoint-ip            string      $CONTROLLER_HOSTNAME"
sudo debconf-set-selections <<< "packagename  cinder/region-name            string      $REGION_NAME"
sudo apt-get install cinder-api -y 


sudo apt-get install cinder-scheduler -y

# Set the database connection details
# using single quotes for the SEARCH is important
SEARCH='#connection=sqlite:///$state_path/$sqlite_db'
REPLACE="connection=mysql://$CINDER_DB_USER:$CINDER_DBPASS@$CONTROLLER_HOSTNAME/$CINDER_DB_NAME"
FILEPATH="/etc/cinder/cinder.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH


# Create the cinder database
mysql -u root -p$ROOT_DB_PASS -e "CREATE DATABASE $CINDER_DB_NAME;"
mysql -u root -p$ROOT_DB_PASS -e "GRANT ALL PRIVILEGES ON $CINDER_DB_NAME.* TO '$CINDER_DB_USER'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';"
mysql -u root -p$ROOT_DB_PASS -e "GRANT ALL PRIVILEGES ON $CINDER_DB_NAME.* TO '$CINDER_DB_USER'@'%' IDENTIFIED BY '$CINDER_DBPASS';"

# Create the database tables for the Block Storage service:
sudo su -s /bin/sh -c "cinder-manage db sync" $CINDER_DB_NAME



# create the nova user
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT
export OS_USERNAME="admin"
export OS_PASSWORD="$ADMIN_PASS"
export OS_TENANT_NAME="admin"
export OS_AUTH_URL="http://$CONTROLLER_HOSTNAME:35357/v2.0"

# Create the cinder user to authenticate with the identity service
keystone user-create --name=$CINDER_USER --pass=$CINDER_PASS --email=$ADMIN_EMAIL
keystone user-role-add --user=$CINDER_USER --tenant=$SERVICE_TENANT_NAME --role=admin


# Register the Block Storage service with the Identity service so that other OpenStack services 
# can locate it:
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s

# Register the block storage service with the identity service so that other openstack services 
# can locate it.
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_HOSTNAME:8776/v1/%\(tenant_id\)s

# Register a service and endpoint for version 2 of the Block Storage service API:
keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
--publicurl=http://$CONTROLLER_HOSTNAME:8776/v2/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_HOSTNAME:8776/v2/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_HOSTNAME:8776/v2/%\(tenant_id\)s


# Start and configure the Block Storage services to start when the system boots:
sudo service openstack-cinder-api start
sudo service openstack-cinder-scheduler start