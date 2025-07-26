#!/bin/bash

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Print minetest version
printf "\033[1m\033[33mcontainer@pelican~ \033[0mluantiserver --version\n"
luantiserver --version

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}

if [ -n "$WEBHOOK_URL" ]; then
    log_file=$(ls -t /home/container/.minetest/logs 2>/dev/null | head -n1)

    if [ -z "$log_file" ]; then 
        log_file="../server.log"
    fi

    out=$(tail -n20 /home/container/.minetest/logs/"$log_file")

    errors=$(echo "$out" | grep -i ERROR > /dev/null)

    if [ $? -eq 0 ]; then
        echo "$errors" | jq -Rs \
            --arg prefix 'Server Crashed: ```' --arg suffix '```' '{content: ($prefix + . + $suffix)}' \
            | curl -X POST -H "Content-Type: application/json" -d @- "$WEBHOOK_URL"
    fi
fi

