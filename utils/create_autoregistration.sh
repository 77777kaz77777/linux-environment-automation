#!/bin/bash
# File: create_autoregistration.sh
# Description: Creates the Zabbix Autoregistration rule via API using curl and jq.

ZABBIX_API="http://127.0.0.1/api_jsonrpc.php"
USERNAME="Admin"
PASSWORD="zabbix"

# Ensure jq is installed for JSON parsing
if ! command -v jq &>/dev/null; then
  echo "Installing required package 'jq'..."
  dnf install -y jq
fi

echo "Authenticating with Zabbix API..."
AUTH_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" -d '{
  "jsonrpc": "2.0",
  "method": "user.login",
  "params": {"username": "'"$USERNAME"'", "password": "'"$PASSWORD"'"},
  "id": 1
}' $ZABBIX_API | jq -r '.result')

if [ "$AUTH_TOKEN" == "null" ] || [ -z "$AUTH_TOKEN" ]; then
  echo "Error: Authentication failed. Check your password."
  exit 1
fi

echo "Retrieving Group ID for 'Linux servers'..."
GROUP_ID=$(curl -s -X POST -H "Content-Type: application/json" -d '{
  "jsonrpc": "2.0",
  "method": "hostgroup.get",
  "params": {"filter": {"name": ["Linux servers"]}},
  "auth": "'"$AUTH_TOKEN"'",
  "id": 2
}' $ZABBIX_API | jq -r '.result[0].groupid')

echo "Retrieving Template ID for 'Linux by Zabbix agent'..."
TEMPLATE_ID=$(curl -s -X POST -H "Content-Type: application/json" -d '{
  "jsonrpc": "2.0",
  "method": "template.get",
  "params": {"filter": {"host": ["Linux by Zabbix agent"]}},
  "auth": "'"$AUTH_TOKEN"'",
  "id": 3
}' $ZABBIX_API | jq -r '.result[0].templateid')

echo "Creating Autoregistration Action..."
curl -s -X POST -H "Content-Type: application/json" -d '{
  "jsonrpc": "2.0",
  "method": "action.create",
  "params": {
    "name": "Auto-Register Linux VMs",
    "eventsource": 2,
    "status": 0,
    "filter": {
      "evaltype": 0,
      "conditions": [{"conditiontype": 22, "operator": 2, "value": "Test-VM"}]
    },
    "operations": [
      {"operationtype": 2},
      {"operationtype": 4, "opgroup": [{"groupid": "'"$GROUP_ID"'"}]},
      {"operationtype": 6, "optemplate": [{"templateid": "'"$TEMPLATE_ID"'"}]}
    ]
  },
  "auth": "'"$AUTH_TOKEN"'",
  "id": 4
}' $ZABBIX_API | jq .

echo "Autoregistration rule successfully created."
