#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"
BASE_URL="${OPENMRS_BASE_URL:-http://localhost/openmrs}"
OPENMRS_USERNAME="${OPENMRS_USER:-admin}"
OPENMRS_PASSWORD="${OPENMRS_PASSWORD:-Admin123}"
CONTENT_TYPE="Content-Type: application/json"

if ! command -v curl &> /dev/null; then
    echo "curl could not be found. Please install curl to run this script."
    exit 1
fi

AUTH_HEADER="Authorization: Basic $(echo -n "$OPENMRS_USERNAME:$OPENMRS_PASSWORD" | base64)"
CONCEPTS_TO_RETIRE_FILE="$script_dir/concepts_to_retire.txt"

if [[ ! -f "$CONCEPTS_TO_RETIRE_FILE" ]]; then
    echo "File '$CONCEPTS_TO_RETIRE_FILE' not found. Please create this file with concept UUIDs to retire."
    exit 1
fi

while IFS= read -r UUID; do
    if [[ -n "$UUID" ]]; then
        echo "Retiring concept with UUID: $UUID"
        curl --location --request DELETE "$BASE_URL/ws/rest/v1/concept/$UUID" \
            --header "$CONTENT_TYPE" \
            --header "$AUTH_HEADER"
    fi
done < "$CONCEPTS_TO_RETIRE_FILE"
echo "All specified concepts have been retired."
