sudo mkdir -p "/mnt/${SVC_NAME}_tmp"
sudo mount -t tmpfs -o size=256M tmpfs "/mnt/${SVC_NAME}_tmp"
sudo chown "${SVC_NAME}:${SVC_NAME}" "/mnt/${SVC_NAME}_tmp"
df -h "/mnt/${SVC_NAME}_tmp"
