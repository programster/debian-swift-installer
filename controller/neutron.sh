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
NEUTRON_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $NEUTRON_SCRIPTPATH/../config.sh

# Before we can install nova, we need to configure the host as a neutron server
sudo debconf-set-selections <<< "neutron-common  neutron/auth-host              string      $CONTROLLER_PRIVATE_IP"
sudo debconf-set-selections <<< "neutron-common  neutron/admin-tenant-name      string      $SERVICE_TENANT_NAME"
sudo debconf-set-selections <<< "neutron-common  neutron/admin-user             string      $NEUTRON_USER"
sudo debconf-set-selections <<< "neutron-common  neutron/admin-password         password    $NEUTRON_PASS"
sudo debconf-set-selections <<< "neutron-common  neutron/plugin-select          select      LinuxBridge"
sudo debconf-set-selections <<< "neutron-common  neutron/configure_db           boolean     false"
sudo debconf-set-selections <<< "neutron-common  neutron/rabbit_host            string      $CONTROLLER_HOSTNAME"
sudo debconf-set-selections <<< "neutron-common  neutron/rabbit_userid          string      $RABBIT_USER"
sudo debconf-set-selections <<< "neutron-common  neutron/rabbit_password        password    $RABBIT_PASS"
sudo debconf-set-selections <<< "neutron-common  neutron/tenant_network_type    select      gre"
sudo debconf-set-selections <<< "neutron-common  neutron/enable_tunneling       boolean     false"
sudo debconf-set-selections <<< "neutron-common  neutron/tunnel_id_ranges       string      1:1000"
sudo debconf-set-selections <<< "neutron-common  neutron/local_ip               string      $CONTROLLER_PRIVATE_IP"
sudo apt-get install neutron-common -y

mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "CREATE DATABASE $NEUTRON_DB_NAME;"
mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON $NEUTRON_DB_NAME.* TO '$NEUTRON_DB_USER'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';"
mysql -u root -p"$ROOT_DB_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON $NEUTRON_DB_NAME.* TO '$NEUTRON_DB_USER'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';"

# Create the compute service tables.
neutron-manage db sync $NEUTRON_DB_NAME

sudo debconf-set-selections <<< "neutron-server  neutron/register-endpoint      boolean     false"
sudo debconf-set-selections <<< "neutron-server  neutron/keystone-ip            string      $CONTROLLER_PRIVATE_IP"
sudo debconf-set-selections <<< "neutron-server  neutron/keystone-auth-token    password    $ADMIN_TOKEN"
sudo debconf-set-selections <<< "neutron-server  neutron/endpoint-ip            string      $CONTROLLER_PRIVATE_IP"
sudo debconf-set-selections <<< "neutron-server  neutron/region-name            string      $REGION_NAME"
sudo apt-get install neutron-server -y

# create the neutron user/endpoint
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT
export OS_USERNAME="admin"
export OS_PASSWORD="$ADMIN_PASS"
export OS_TENANT_NAME="admin"
export OS_AUTH_URL="http://$CONTROLLER_HOSTNAME:35357/v2.0"

keystone user-create --name=$NEUTRON_USER --pass=$NOVA_PASS --email=$ADMIN_EMAIL
keystone user-role-add --user=$NEUTRON_USER --tenant=$SERVICE_TENANT_NAME --role=admin
keystone service-create --name=$NEUTRON_USER --type=network --description="OpenStack Networking"

keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ network / {print $2}') \
  --publicurl http://$CONTROLLER_HOSTNAME:9696 \
  --adminurl http://$CONTROLLER_HOSTNAME:9696 \
  --internalurl http://$CONTROLLER_HOSTNAME:9696