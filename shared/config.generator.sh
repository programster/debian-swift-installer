#!/bin/bash
if ! [ -n "$BASH_VERSION" ];then
    echo "this is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

GENERATOR_SCRIPTPATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

function confirm()
{
    read TMP_VAR

    case "$TMP_VAR" in
        [yY] | [yY][eE][sS])
            RESULT=true
        ;;
        *)
            RESULT=false
        ;;
    esac
}

echo ""
echo "*==================*"
echo "| Config Generator |"
echo "*==================*"

if [ ! -f $GENERATOR_SCRIPTPATH/../config.sh ]; then
    echo "Config file not found, generating a new one."
else
    # source the config to load any vars that are already set.
    source $GENERATOR_SCRIPTPATH/../config.sh
    echo "sourcing $GENERATOR_SCRIPTPATH/../config.sh"
fi 


# Define the hostname of the controller.
if [ -z "$CONTROLLER_HOSTNAME" ]; then
    echo ""
    echo "Please enter the hostname for accessing the control server."
    echo "This should not be publicly available and can just be the private IP of the controller"
    read -e -i "controller.mydomain.com" CONTROLLER_HOSTNAME
    echo "CONTROLLER_HOSTNAME=$CONTROLLER_HOSTNAME" >> $GENERATOR_SCRIPTPATH/../config.sh
fi


# Define the private IP of the controller
if [ -z "$CONTROLLER_PRIVATE_IP" ]; then
    echo ""
    echo "This hosts IPs (for reference)"
    hostname -I | xargs | tr [:space:] '\n'
    echo ""
    echo "Please enter the private IP of the controller server."
    echo "This is the IP of the server on the internal (non public) LAN"
    read CONTROLLER_PRIVATE_IP
    echo "CONTROLLER_PRIVATE_IP=$CONTROLLER_PRIVATE_IP" >> $GENERATOR_SCRIPTPATH/../config.sh
fi


# Define the email address of the admin
if [ -z "$ADMIN_EMAIL" ]; then
    echo ""
    echo "Please enter the admin's email address: "
    read ADMIN_EMAIL
    echo "ADMIN_EMAIL=$ADMIN_EMAIL" >> $GENERATOR_SCRIPTPATH/../config.sh
fi


# Check for passwords and if not set, then auto generate one.
PASSWORDS=()
PASSWORDS+=("DATABASE_PASS")
PASSWORDS+=("RABBIT_PASS")
PASSWORDS+=("KEYSTONE_DBPASS")
PASSWORDS+=("ADMIN_TOKEN")
PASSWORDS+=("ADMIN_PASS")
PASSWORDS+=("DASH_DBPASS")
passwords+=("SWIFT_HASH_PATH_SUFFIX")

for VAR_NAME in "${PASSWORDS[@]}"
do
    :
    VALUE=${!VAR_NAME}
    if [ -z "$VALUE" ]; then
        echo "Creating a randomly generated password for: $VAR_NAME"
        NEW_PASS=`openssl rand -hex 16`
        echo "`echo $VAR_NAME`=`echo $NEW_PASS`" >> $GENERATOR_SCRIPTPATH/../config.sh
    fi
done

