#!/bin/bash
# glance is openstacks image service
# http://docs.openstack.org/icehouse/install-guide/install/apt/content/glance-install.html

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
CINDER_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $CINDER_SCRIPTPATH/../config.sh


#!/bin/bash
# http://docs.openstack.org/icehouse/install-guide/install/yum/content/cinder-controller.html

# This scenario configures OpenStack Block Storage services on the Controller node and assumes 
# that a second node provides storage through the cinder-volume service.

sudo apt-get install openstack-cinder -y

# Configure Block Storage to use your database.
sudo openstack-config --set /etc/cinder/cinder.conf \
database connection mysql://cinder:$CINDER_DBPASS@$CONTROLLER_HOSTNAME/cinder

# Create the cinder database
mysql -u root -p
mysql -u root -p$ROOT_DB_PASS -e "CREATE DATABASE $CINDER_DB_NAME;"
mysql -u root -p$ROOT_DB_PASS -e "GRANT ALL PRIVILEGES ON $CINDER_DB_NAME.* TO '$CINDER_DB_USER'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';"
mysql -u root -p$ROOT_DB_PASS -e "GRANT ALL PRIVILEGES ON $CINDER_DB_NAME.* TO 'CINDER_DB_USER'@'%' IDENTIFIED BY '$CINDER_DBPASS';"

# Create the database tables for the Block Storage service:
sudo cinder-manage db sync $CINDER_DB_NAME


# Create the cinder user to authenticate with the identity service
keystone user-create --name=cinder --pass=CINDER_PASS --email=cinder@example.com
keystone user-role-add --user=cinder --tenant=service --role=admin

# Edit the /etc/cinder/cinder.conf configuration file:

openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$CONTROLLER_HOSTNAME:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_host controller
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken admin_password $CINDER_PASS


# Configure Block Storage to use the Qpid message broker:
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend qpid
openstack-config --set /etc/cinder/cinder.conf DEFAULT qpid_hostname controller

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


