#!/usr/bin/env bash

###
#  Modified by: Jeff D.
#  Modified date: 11/13/18
#
###

###
#  Details:
#  This script will pull an inventory of all instances, containers, and buckets in Google Cloud projects for an organization. It
#  can then send out a report via SendGrid API.
#
#  This program is a free software; you can redistribute it and/or modify it under the terms of the gnu general public
#  license (version 2) as published by the fsf - free software foundation.
###

# Setup Variables. Please be sure to fill in the empty "".
SUBJECTDATE="$(date)"
SENDGRID_API_KEY=""
EMAIL_TO=""
FROM_EMAIL=""
FROM_NAME="GCloud Report"
SUBJECT="GCloud Compute and Storage Inventory - $SUBJECTDATE"
total_instances=0
total_containers=0
total_projects=0
total_buckets=0

# Report pull for all Google Cloud projects.
echo -n "<p><b>Google Cloud Instance, Container, and Storage Inventory</b>" >> inventory.txt;
echo -n "<br>~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> inventory.txt;
for project in $(gcloud projects list --format="value(projectId)" --sort-by=projectId);
    do
        gcloud config set project $project;
        gcloud compute instances list -q |sed -n '1!p'|nl |tee instance_list.txt;
        instance_count="$(cat instance_list.txt| grep -v "gke" |awk 'END {print$1}')";
        container_count="$(cat instance_list.txt| grep "gke" |awk 'END {print$1}')";
        bucket_list="$(gsutil ls)";
        if [ -z "$container_count" ]
        then
                container_count=0;
        fi
        if [ -z "$instance_count" ]
        then
                instance_count=0;
        fi
        if [ -z "$bucket_list" ]
        then
                  bucket_count=0;
        else
                  gsutil ls |nl >> buckets.txt;
                  bucket_count="$(cat buckets.txt|awk 'END {print$1}')";
    	fi
        project_title="<br>$project";
        project_instance_count="<br> - Instance Count: $instance_count";
        project_container_count="<br> - Container Count: $container_count";
        project_bucket_count="<br> - Bucket Count: $bucket_count";
        echo -n "$project_title" >> inventory.txt;
        echo -n "$project_instance_count" >> inventory.txt;
        echo -n "$project_container_count" >> inventory.txt;
        echo -n "$project_bucket_count" >> inventory.txt;
        echo -n "<br>==================================" >> inventory.txt;
        total_instances=$((instance_count + total_instances));
        total_containers=$((container_count + total_containers));
        total_buckets=$((bucket_count + total_buckets));
        total_projects=$((total_projects +1));
done
echo -n "<br>Total Instances All Projects: $total_instances" >> inventory.txt;
echo -n "<br>Total Containers All Projects: $total_containers" >> inventory.txt;
echo -n "<br>Total Buckets All Projects: $total_buckets" >> inventory.txt;
echo -n "<br>Total Projects: $total_projects" >> inventory.txt;
#Email the inventory
echo -n "</p>" >> inventory.txt;

full_inventory="$(cat inventory.txt)";

htmldata=$full_inventory;

# Send report via SendGrid API.

maildata='{"personalizations": [{"to": [{"email": "'${EMAIL_TO}'"}]}],"from": {"email": "'${FROM_EMAIL}'",
    "name": "'${FROM_NAME}'"},"subject": "'${SUBJECT}'","content": [{"type": "text/html", "value": "'${htmldata}'"}]}'

curl --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header 'authorization: Bearer '$SENDGRID_API_KEY \
  --header 'content-type: application/json' \
  --data "'$maildata'"

# Remove inventory files.
rm -f instance_list.txt buckets.txt inventory.txt