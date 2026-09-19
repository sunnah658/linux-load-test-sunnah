#!/bin/bash

SVC_NAME="${SVC_NAME:-bgdsvc_sunnah658}"

# Check if the user already exists
if id "$SVC_NAME" &>/dev/null; then
    echo "User '$SVC_NAME' already exists. No action needed."
else
    echo "Creating service account '$SVC_NAME'..."
    # Create the dedicated service identity without login privileges
    sudo useradd -r -m -s /usr/sbin/nologin "$SVC_NAME"
    echo "User '$SVC_NAME' created successfully."
fi

# Verify the user details
getent passwd "$SVC_NAME"
