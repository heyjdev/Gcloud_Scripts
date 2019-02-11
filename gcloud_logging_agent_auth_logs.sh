#! /bin/bash

###
#  Modified by: Jeff D.
#
###

###
#  Details:
#  This script will install the Google Cloud FluentD logging agent and configure for Auth logs to display in StackDriver.
#
#  This program is a free software; you can redistribute it and/or modify it under the terms of the gnu general public
#  license (version 2) as published by the fsf - free software foundation.
###

FLUENTD=$(ls /usr/sbin/google-fluentd)
if [ -z "$FLUENTD" ]; then
cd /home/
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh
cat <<EOF >/etc/google-fluentd/config.d/audit.conf
<source>
@type tail
# Format 'none' indicates the log is unstructured (text).
format none
# The path of the log file.
path /var/log/auth.log
# The path of the position file that records where in the log file
# we have processed already. This is useful when the agent
# restarts.
pos_file /var/lib/google-fluentd/pos/audit.pos
read_from_head true
# The log tag for this log input.
tag audit-log
</source>
EOF
service google-fluentd restart
fi
