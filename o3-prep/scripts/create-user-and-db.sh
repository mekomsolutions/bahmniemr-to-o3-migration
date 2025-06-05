#!/bin/bash

set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the .env file if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a  # automatically export all variables
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Error: .env file not found in $PROJECT_ROOT"
    exit 1
fi

# Validate required environment variables
required_vars=(
    "MYSQL_HOST"
    "MYSQL_ROOT_PASSWORD"
    "OPENMRS_DB_NAME"
    "OPENMRS_DB_USER"
    "OPENMRS_DB_PASSWORD"
    "EIP_DB_NAME_SENAITE"
    "EIP_DB_USER_SENAITE"
    "EIP_DB_PASSWORD_SENAITE"
    "EIP_DB_NAME_ODOO"
    "EIP_DB_USER_ODOO"
    "EIP_DB_PASSWORD_ODOO"
    "EIP_DB_NAME_KEYCLOAK"
    "EIP_DB_USER_KEYCLOAK"
    "EIP_DB_PASSWORD_KEYCLOAK"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

function create_user_and_database() {
docker exec -i $MYSQL_HOST mysql --password=$MYSQL_ROOT_PASSWORD --user=root <<MYSQL_SCRIPT
    CREATE DATABASE IF NOT EXISTS $1;
    CREATE USER IF NOT EXISTS '$2'@'localhost' IDENTIFIED BY '$3';
    CREATE USER IF NOT EXISTS '$2'@'%' IDENTIFIED BY '$3';
    GRANT ALL PRIVILEGES ON $1.* TO '$2'@'localhost';
    GRANT ALL PRIVILEGES ON $1.* TO '$2'@'%';
    FLUSH PRIVILEGES;
MYSQL_SCRIPT
}

create_db_user_with_validation() {
	local dbName="$1"
	local dbUser="$2"
	local dbUserPassword="$3"
	if [ -n "$dbName" ] && [ -n "$dbUser" ] && [ -n "$dbUserPassword" ]; then
		create_user_and_database "$dbName" "$dbUser" "$dbUserPassword"
	fi
}

echo "Creating '${OPENMRS_DB_USER}' user and '${OPENMRS_DB_NAME}' database..."
create_db_user_with_validation "${OPENMRS_DB_NAME}" "${OPENMRS_DB_USER}" "${OPENMRS_DB_PASSWORD}"

echo "Creating '${EIP_DB_USER_SENAITE}' user and '${EIP_DB_NAME_SENAITE}' database..."
create_db_user_with_validation "${EIP_DB_NAME_SENAITE}" "${EIP_DB_USER_SENAITE}" "${EIP_DB_PASSWORD_SENAITE}"

echo "Creating '${EIP_DB_USER_ODOO}' user and '${EIP_DB_NAME_ODOO}' database..."
create_db_user_with_validation "${EIP_DB_NAME_ODOO}" "${EIP_DB_USER_ODOO}" "${EIP_DB_PASSWORD_ODOO}"

echo "Creating '${EIP_DB_USER_KEYCLOAK}' user and '${EIP_DB_NAME_KEYCLOAK}' database..."
create_db_user_with_validation "${EIP_DB_NAME_KEYCLOAK}" "${EIP_DB_USER_KEYCLOAK}" "${EIP_DB_PASSWORD_KEYCLOAK}"
