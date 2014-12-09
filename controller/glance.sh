# http://docs.openstack.org/icehouse/install-guide/install/apt/content/glance-install.html

sudo apt-get install glance python-glanceclient -y

SEARCH="#connection = <None>"
REPLACE="connection = mysql://glance:$GLANCE_DBPASS@controller/glance"
FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# By default, the Ubuntu packages create an SQLite database. Delete the glance.sqlite file created 
# in the /var/lib/glance/ directory so that it does not get used by mistake:
# S.P. - Could not find this by default?
#sudo rm /var/lib/glance/glance.sqlite


# Create the glance database and user in the mysql db
mysql -u root -p$DATABASE_PASS -h $CONTROLLER_HOSTNAME -e "CREATE DATABASE glance;"
mysql -u root -p$DATABASE_PASS -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';"
mysql -u root -p$DATABASE_PASS -h $CONTROLLER_HOSTNAME -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';"

# create the database tables for the image service
sudo su -s /bin/sh -c "glance-manage db_sync" glance

export OS_USERNAME="admin"
export OS_PASSWORD="$ADMIN_PASS"
export OS_TENANT_NAME="admin"
export OS_AUTH_URL="http://$CONTROLLER_HOSTNAME:35357/v2.0"

# create the glance keystone user
keystone user-create --name=glance --pass=$GLANCE_PASS --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin

# Configure the Image Service to use the Identity Service for authentication.
SEARCH="auth_host = 127.0.0.1"
REPLACE="auth_host = $CONTROLLER_HOSTNAME"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH


SEARCH="admin_tenant_name = %SERVICE_TENANT_NAME%"
REPLACE="admin_tenant_name = service"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH


SEARCH="admin_user = %SERVICE_USER%"
REPLACE="admin_user = glance"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH


SEARCH="admin_password = %SERVICE_PASSWORD%"
REPLACE="admin_password = $GLANCE_PASS"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# add the AUTH URI
SEARCH="\[keystone_authtoken\]"
REPLACE="\[keystone_authtoken\]\nauth_uri = http://$CONTROLLER_HOSTNAME:5000"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

# add flavor to paste_deploy section
SEARCH="#flavor="
REPLACE="flavor = keystone"
FILEPATH="/etc/glance/glance-api.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

FILEPATH="/etc/glance/glance-registry.conf"
sudo sed -i "s;$SEARCH;$REPLACE;" $FILEPATH

#register the image service with identity so that other services can locate it
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://$CONTROLLER_HOSTNAME:9292 \
--internalurl=http://$CONTROLLER_HOSTNAME:9292 \
--adminurl=http://$CONTROLLER_HOSTNAME:9292

service glance-registry restart
service glance-api restart


