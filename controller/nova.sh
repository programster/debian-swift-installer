clear
echo "installing compute capability (not the node)"
sleep 1

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
REPLACE="connection = mysql://nova:$NOVA_DBPASS@controller/nova"
FILEPATH="/etc/nova/nova.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# append to the nova config file
sudo echo "rpc_backend = rabbit
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
admin_user = nova
admin_password = $NOVA_PASS

[database]
connection = mysql://nova:$NOVA_DBPASS@controller/nova" >> /etc/nova/nova.conf

rm /var/lib/nova/nova.sqlite


mysql -u root -p"$DATABASE_PASS" -h $CONTROLLER_HOSTNAME -e "CREATE DATABASE nova;"
mysql -u root -p"$DATABASE_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p"$DATABASE_PASS" -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"

# Create the compute service tables.
su -s /bin/sh -c "nova-manage db sync" nova

# create the nova user
unset OS_SERVICE_TOKEN
unset OS_SERVICE_ENDPOINT
export OS_USERNAME="admin"
export OS_PASSWORD="$ADMIN_PASS"
export OS_TENANT_NAME="admin"
export OS_AUTH_URL="http://$CONTROLLER_HOSTNAME:35357/v2.0"
keystone user-create --name=nova --pass=NOVA_PASS --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin


# register compute with the identity service
keystone service-create --name=nova --type=compute --description="OpenStack Compute"

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

# verify installation
nova image-list

echo "if you dont see a table above, something went wrong."
echo "compute installation finished."