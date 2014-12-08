#!/bin/bash
# This is the bare installation of the controller with the identity service.
# http://docs.openstack.org/icehouse/install-guide/install/apt/content/


if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

if [ "$USER" != "root" ]; then
    echo "You need to run me with sudo!"
    exit
fi


KEYSTONE_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


# load the config file.
source $KEYSTONE_SCRIPTPATH/../../config.sh

#########################################################################


# install the database

# Automatically install the mysql server with the root password from our config
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DATABASE_PASS"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DATABASE_PASS"
sudo apt-get install mysql-server -y

# install the python extension.
sudo apt-get install python-mysqldb -y

## replace the bind address
SEARCH="bind-address.*"
REPLACE="bind-address = $CONTROLLER_PRIVATE_IP"
FILEPATH="/etc/mysql/my.cnf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

#SEARCH="\[mysqld\]"
#REPLACE="\[mysqld\]\ndefault-storage-engine = innodb\ninnodb_file_per_table\ncollation-server = utf8_general_ci\ninit-connect = 'SET NAMES utf8'\ncharacter-set-server = utf8"
#FILEPATH="/etc/mysql/my.cnf"
#sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

sudo service mysql restart

#sudo mysql_install_db
#sudo mysql_secure_installation


# Install packages
sudo apt-get install python-software-properties -y


# Install message server
sudo apt-get install rabbitmq-server -y
sudo rabbitmqctl change_password guest $RABBIT_PASS

# Install the identity service
echo ""
clear
echo "*==================*"
echo "| IMPORTANT NOTICE |"
echo "*==================*"
echo "We are about to install the keystone package."
echo "Enter 'no' to all prompts so that it does NOT try to configure anything"
echo "If it forces you to enter an 'admin token' put any junk in as this script will replace it."
read -p "press any key when you have copied it in order to continue." -n 1 -r
sudo apt-get install keystone -y

# need some screenshots of options here.

# Update the connection information in the config file
SEARCH="connection=sqlite:////var/lib/keystone/keystone.sqlite"
REPLACE="connection=mysql://keystone:$KEYSTONE_DBPASS@$CONTROLLER_PRIVATE_IP/keystone"
FILEPATH="/etc/keystone/keystone.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# remove the sqlite database directory so that it doesnt get used by mistake
sudo rm /var/lib/keystone/keystone.sqlite


## Create a keystone database user:
mysql -u root -p"$DATABASE_PASS" -e "CREATE DATABASE keystonedb";
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON keystonedb.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS'";
mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON keystonedb.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS'";


# create the tables for the identity service
#su -s /bin/sh -c "keystone-manage db_sync" keystone
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone


# replace the admin token.
SEARCH="admin_token = .*"
REPLACE="admin_token = $ADMIN_TOKEN"
FILEPATH="/etc/keystone/keystone.conf"
sudo sed -i "s;$SEARCH;$REPLACE;g" $FILEPATH


sudo service keystone restart
# must run a sleep after the restart to prevent race condition in script as service restart non-blocking
sleep 5

# By default, the Identity Service stores expired tokens in the database indefinitely. 
# While potentially useful for auditing in production environments, the accumulation of expired 
# tokens will considerably increase database size and may decrease service performance, 
# particularly in test environments with limited resources. We recommend configuring a periodic 
# task using cron to purge expired tokens hourly.
# Run the following command to purge expired tokens every hour and log the output to 
# /var/log/keystone/keystone-tokenflush.log:
(sudo crontab -l -u keystone 2>&1 | grep -q token_flush) || \
sudo echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' | sudo tee /var/spool/cron/keystone

echo ""
echo "Successfully installed the identity service."

echo "======================"
echo "defining tenants."


export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://$CONTROLLER_HOSTNAME:35357/v2.0
export OS_AUTH_URL=http://$CONTROLLER_HOSTNAME:35357/v2.0

# Create the admin user, role, and tenant
keystone  user-create --name=admin --pass="$ADMIN_PASS" --email="$ADMIN_EMAIL" 
keystone role-create --name=admin 
keystone tenant-create --name=admin --description="Admin Tenant"

# You must now link the admin user, admin role, and admin tenant together using the user-role-add option: 
keystone user-role-add --user=admin --tenant=admin --role=admin

# Link the admin user, _member_ role, and admin tenant: 
keystone user-role-add --user=admin --role=_member_ --tenant=admin



# Now create a normal user and tenant, and link them to the special _member_ role. 
# You will use this account for daily non-administrative interaction with the OpenStack cloud. 
# You can also repeat this procedure to create additional cloud users with different usernames and passwords. 
# Skip the tenant creation step when creating these additional users. 
keystone user-create --name=demo --pass=$DEMO_PASS --email=$DEMO_EMAIL
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo



# Create the service tenant
# OpenStack services also require a username, tenant, and role to access other OpenStack services. 
# In a basic installation, OpenStack services typically share a single tenant named service. 
# You will create additional usernames and roles under this tenant as you install and configure each service. 
keystone tenant-create --name=service --description="Service Tenant"


## Setup services and API endpoints
# Create a service entry for the Identity Service:
keystone service-create \
--name=keystone \
--type=identity \
--description="Keystone Identity Service"

#Specify an API endpoint for the Identity Service by using the returned service ID. 
# When you specify an endpoint, you provide URLs for the public API, internal API, and admin API. 
# In this guide, the controller host name is used. Note that the Identity Service uses a different 
# port for the admin API.
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl "http://`echo $CONTROLLER_HOSTNAME`:5000/v2.0" \
--internalurl "http://`echo $CONTROLLER_HOSTNAME`:5000/v2.0" \
--adminurl "http://`echo $CONTROLLER_HOSTNAME`:35357/v2.0"


echo "done!"
