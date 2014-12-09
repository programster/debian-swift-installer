#!/bin/bash
# nova is openstacks compute service
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
NOVA_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $NOVA_SCRIPTPATH/../config.sh

sudo debconf-set-selections <<< "nova-common  nova/auth-host                   string       $CONTROLLER_PRIVATE_IP"
sudo debconf-set-selections <<< "nova-common  nova/admin-tenant-name           string       $SERVICE_TENANT_NAME"
sudo debconf-set-selections <<< "nova-common  nova/admin-user                  string       $NOVA_USER"
sudo debconf-set-selections <<< "nova-common  nova/admin-password              password     $NOVA_PASS"
sudo debconf-set-selections <<< "nova-common  nova/configure_db                boolean      false"
sudo debconf-set-selections <<< "nova-common  nova/rabbit_host                 string       localhost"
sudo debconf-set-selections <<< "nova-common  nova/rabbit_userid               string       $RABBIT_USER"
sudo debconf-set-selections <<< "nova-common  nova/rabbit_password             password     $RABBIT_PASS"
sudo apt-get install nova-common -y

sudo apt-get install \
nova-api \
nova-cert \
nova-conductor \
nova-consoleauth \
nova-novncproxy \
nova-scheduler \
python-novaclient -y


## replace the bind address
SEARCH="bind-address.*"
REPLACE="connection = mysql://$NOVA_DB_USER:$NOVA_DBPASS@$CONTROLLER_HOSTNAME/$NOVA_DB_NAME"
FILEPATH="/etc/nova/nova.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# append to the nova config file
echo "rpc_backend = rabbit
rabbit_host = controller
rabbit_password = $RABBIT_PASS
my_ip = $CONTROLLER_PRIVATE_IP
vncserver_listen = $CONTROLLER_PRIVATE_IP
vncserver_proxyclient_address = $CONTROLLER_PRIVATE_IP
auth_strategy = keystone

[keystone_authtoken]
auth_uri = http://$CONTROLLER_HOSTNAME:5000
auth_host = $CONTROLLER_HOSTNAME
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = $NOVA_USER
admin_password = $NOVA_PASS

[database]
connection = mysql://$NOVA_DB_USER:$NOVA_DBPASS@$CONTROLLER_HOSTNAME/$NOVA_DB_NAME" | sudo tee -a /etc/nova/nova.conf

rm /var/lib/nova/nova.sqlite


mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "CREATE DATABASE $NOVA_DB_NAME;"
mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON $NOVA_DB_NAME.* TO '$NOVA_DB_USER'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON $NOVA_DB_NAME.* TO '$NOVA_DB_USER'@'%' IDENTIFIED BY '$NOVA_DBPASS';"

# Create the compute service tables.
su -s /bin/sh -c "nova-manage db sync" nova

# create the nova user
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT
export OS_USERNAME="admin"
export OS_PASSWORD="$ADMIN_PASS"
export OS_TENANT_NAME="admin"
export OS_AUTH_URL="http://$CONTROLLER_HOSTNAME:35357/v2.0"

keystone user-create --name=$NOVA_USER --pass=$NOVA_PASS --email=$ADMIN_EMAIL
keystone user-role-add --user=$NOVA_USER --tenant=$SERVICE_TENANT_NAME --role=admin
keystone service-create --name=$NOVA_USER --type=compute --description="OpenStack Compute"

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://$CONTROLLER_HOSTNAME:8774/v2/%\(tenant_id\)s \
--internalurl=http://$CONTROLLER_HOSTNAME:8774/v2/%\(tenant_id\)s \
--adminurl=http://$CONTROLLER_HOSTNAME:8774/v2/%\(tenant_id\)s


# restart compute services
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

# verify installation when debugging
if false; then
    nova image-list
    echo "if you dont see a table above, something went wrong."
    echo "compute installation finished."
fi
