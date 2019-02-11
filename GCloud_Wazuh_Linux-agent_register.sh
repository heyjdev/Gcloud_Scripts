#!/bin/bash

###
#  Modified by: Jeff D.
#  Modified date: 10/17/18
#  OS Type: Linux
###

###
#  Details:
#  This script will install Wazuh agents on new Google Cloud instances and register them with the Wazuh manager.
#  It will also create the group in Wazuh based on the Google Cloud project name and associate the agent with that group. This
#  is helpful with identifying which agents belong to which Google Cloud project.
#
#  This program is a free software; you can redistribute it
#  and/or modify it under the terms of the gnu general public
#  license (version 2) as published by the fsf - free software foundation.
###

# Setup Variables. Please be sure to fill in the empty "" after the Wazuh manager is configured.
API_IP=""
API_PORT="55000"
PROTOCOL="http"
HOST="$(hostname)"
AGENT_NAME="name=$HOST"
USER=""
CREDS=""
DISTRO="$(cat /proc/version)"

# Wazuh installation check and install based on the distribution.
wazuh_install() {
if [ ! -d "/var/ossec/" ]; then
    if echo "$DISTRO" |grep -q "Red"; then
    cat > /etc/yum.repos.d/wazuh.repo <<\EOF
[wazuh_repo]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/3.x/yum/
protect=1
EOF
    yum install -y wazuh-agent
    elif echo "$DISTRO" |grep -q 'Ubuntu\|Debian'; then
    apt-get install -y curl apt-transport-https lsb-release
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
    echo "deb https://packages.wazuh.com/3.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
    apt-get update
    apt-get install -y wazuh-agent
    else
    echo "Distribution not supported or still needs to be added"
    fi
else
 echo "Found OSSEC, moving on to register agent..."
fi
}

# Adding agent and getting id from the Wazuh manager.
register_agent() {
echo ""
echo "adding agent:"
API_RESULT=$(curl -s -u $USER:$CREDS -k -X POST -d $AGENT_NAME $PROTOCOL://$API_IP:$API_PORT/agents)
echo -e $API_RESULT | grep -q "\"error\":0" 2>&1

if [ "$?" != "0" ]; then
 echo -e $API_RESULT | sed -rn 's/.*"message":"(.+)".*/\1/p'
 exit 1
fi

# Get agent id and agent key
AGENT_ID=$(echo $API_RESULT | cut -d':' -f 4 | cut -d ',' -f 1)
AGENT_KEY=$(echo $API_RESULT | cut -d':' -f 5 | cut -d '}' -f 1)

echo "Agent '$AGENT_NAME' with ID '$AGENT_ID' added."
echo "Key for agent '$AGENT_ID' received."

# Importing key
echo ""
echo "Importing authentication key:"
echo "y" | /var/ossec/bin/manage_agents -i $AGENT_KEY

# Edit ossec config with Manager IP
if [ -z $(grep $API_IP "/var/ossec/etc/ossec.conf") ]; then
 sed -i 's/MANAGER_IP/'$API_IP'/' /var/ossec/etc/ossec.conf
else
 echo "$API_IP is found in the ossec.conf"
fi

# Restarting agent
echo ""
echo "Restarting:"
echo ""
/var/ossec/bin/ossec-control restart
}

# Create group in Wazuh console from the Google Cloud project name and add the agent to the group.
agent_group_add() {
INSTANCE_PROJECT="$(gcloud config list --format="text" |grep project |tr -d -| awk '{print $2}')"
curl -u $USER:$CREDS -k -X PUT $PROTOCOL://$API_IP:$API_PORT/agents/groups/$INSTANCE_PROJECT
AGENT_ID=$(curl -s -u $USER:$CREDS -X GET $PROTOCOL://$API_IP:$API_PORT/agents/name/$HOST | rev | cut -d: -f1 | rev | grep -o '".*"' | tr -d '"')
curl -u $USER:$CREDS -k -X PUT $PROTOCOL://$API_IP:$API_PORT/agents/$AGENT_ID/group/$INSTANCE_PROJECT
}

# Run all functions.
wazuh_install &&
register_agent &&
sleep 5
agent_group_add

