# http://docs.openstack.org/havana/install-guide/install/apt-debian/content/general-installation-steps-swift.html

# Create a service entry for the Object Storage Service:
keystone service-create --name=swift --type=object-store --description="Object Storage Service"

keystone endpoint-create \
--service-id=the_service_id_above \
--publicurl='http://$CONTROLLER_HOSTNAME:8080/v1/AUTH_%(tenant_id)s' \
--internalurl='http://$CONTROLLER_HOSTNAME:8080/v1/AUTH_%(tenant_id)s' \
--adminurl=http://$CONTROLLER_HOSTNAME:8080

# Create the configuration directory on all nodes:
mkdir -p /etc/swift

# Create /etc/swift/swift.conf on all nodes:
echo "[swift-hash]
# random unique string that can never change (DO NOT LOSE)
swift_hash_path_suffix = $SWIFT_HASH_PATH_SUFFIX" | sudo tee /etc/swift/swift.conf