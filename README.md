# Linux Service Lifecycle Lab

A small lab where I create a fake service on Linux, stress test it, give it SSH access, lock that access down, automate its monitoring, and then clean everything up.

Done on one laptop, no cloud server needed.

---

## Setup

```bash
export SVC_NAME=bgdsvc_sunnah658
```

Run this once per terminal session. Note: `$SVC_NAME` only works in the shell — inside config files (sshd_config, logrotate, crontab) you have to type the actual name out.

---

## Repo contents

```
├── README.md
├── scripts/
│   ├── 01_create_user.sh
│   ├── 02_setup_tmpfs.sh
│   ├── 03_stress_and_populate.sh
│   ├── 04_cleanup.sh
│   ├── bgdsvc_sunnah658_monitor.sh
│   └── bgdsvc_sunnah658_cleanup_old_files.sh
├── screenshots/
│   ├── 00_svc_name.png
│   ├── 01_id_created.png
│   ├── 02_df_before.png
│   ├── 02_df_after.png
│   ├── 03_free_before.png
│   ├── 03_free_during.png
│   ├── 03_free_after.png
│   ├── 03_dmesg_oom.png
│   ├── 04_ssh_success.png
│   ├── 05_crontab_l.png
│   └── 06_cleanup_verify.png
└── observations.md
```

---

## Part 1 — Create the service account

```bash
sudo useradd -r -m -s /usr/sbin/nologin "$SVC_NAME"
id "$SVC_NAME"
getent passwd "$SVC_NAME"
```

`nologin` means the account can own files and run processes, but nobody can log in as it. Service accounts should never be login accounts.

**Deliverable:** `01_create_user.sh` (safe to run twice)

---

## Part 2 — Add scratch space (tmpfs)

```bash
sudo mkdir -p "/mnt/${SVC_NAME}_tmp"
sudo mount -t tmpfs -o size=256M tmpfs "/mnt/${SVC_NAME}_tmp"
sudo chown "$SVC_NAME:$SVC_NAME" "/mnt/${SVC_NAME}_tmp"
df -h "/mnt/${SVC_NAME}_tmp"
```

⚠️ Don't skip `size=256M`. Without it, tmpfs can eat all your RAM.

**Deliverable:** `02_setup_tmpfs.sh`

---

## Part 3 — Stress test it

**Fill the disk:**
```bash
for i in $(seq 1 20); do
  dd if=/dev/urandom of="/mnt/${SVC_NAME}_tmp/file_$i.dat" bs=1M count=10
  df -h "/mnt/${SVC_NAME}_tmp"
done
```

**Push the CPU:**
```bash
sudo apt install stress-ng -y
sudo -u "$SVC_NAME" stress-ng --cpu 2 --timeout 30s
```

**Squeeze memory:**
```bash
sudo -u "$SVC_NAME" stress-ng --vm 1 --vm-bytes 200M --timeout 30s
```

**All at once** (watch from a second terminal):
```bash
free -h
top
dmesg | grep -i oom
```

If `oom` shows up, the kernel killed a process to save the system — same thing that happens on real servers under load.

**Deliverable:** `03_stress_and_populate.sh` with `--cpu`, `--mem`, `--disk`, `--all` flags

---

## Part 4 — Add SSH access

```bash
ssh-keygen -t ed25519 -f ~/.ssh/${SVC_NAME}_key
sudo mkdir -p "/home/$SVC_NAME/.ssh"
sudo cp ~/.ssh/${SVC_NAME}_key.pub "/home/$SVC_NAME/.ssh/authorized_keys"
sudo chown -R "$SVC_NAME:$SVC_NAME" "/home/$SVC_NAME/.ssh"
sudo chmod 700 "/home/$SVC_NAME/.ssh"
sudo chmod 600 "/home/$SVC_NAME/.ssh/authorized_keys"
```

One laptop only? Install the SSH server and connect to yourself:
```bash
sudo apt install openssh-server -y
sudo systemctl enable --now ssh
ssh "$SVC_NAME"@localhost
```

> Service is named `ssh` on Debian/Ubuntu, `sshd` on RHEL/Fedora/Rocky. Check with `systemctl status ssh sshd 2>/dev/null`.

---

## Part 5 — Harden SSH

```bash
sudo nano /etc/ssh/sshd_config
```

```
Port 2222
PermitRootLogin no
PasswordAuthentication no
AllowUsers bgdsvc_sunnah658
```

```bash
sudo systemctl restart ssh
ssh -i ~/.ssh/${SVC_NAME}_key -p 2222 "$SVC_NAME"@localhost
```

⚠️ **Two things to remember:**
- On a remote server, open the new port in the firewall *before* changing it — otherwise you lock yourself out.
- `AllowUsers` blocks everyone else, including your own login. Make sure you have another way in before restarting sshd on anything remote.

---

## Part 6 — Automate monitoring (cron)

**Monitor script** (`/usr/local/bin/${SVC_NAME}_monitor.sh`):
```bash
#!/bin/bash
SVC_NAME="bgdsvc_sunnah658"
LOGFILE="/var/log/${SVC_NAME}/monitor.log"
echo "---- $(date) ----" >> "$LOGFILE"
free -h >> "$LOGFILE"
df -h "/mnt/${SVC_NAME}_tmp" >> "$LOGFILE" 2>&1
ps -u "$SVC_NAME" >> "$LOGFILE" 2>&1
```

**Cleanup script** (`/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh`):
```bash
#!/bin/bash
SVC_NAME="bgdsvc_sunnah658"
TMPDIR="/mnt/${SVC_NAME}_tmp"
LOGFILE="/var/log/${SVC_NAME}/monitor.log"
find "$TMPDIR" -type f -mtime +1 -delete
echo "$(date): cleanup run — removed files older than 1 day" >> "$LOGFILE"
```

Schedule both:
```bash
sudo chmod +x /usr/local/bin/${SVC_NAME}_monitor.sh
sudo chmod +x /usr/local/bin/${SVC_NAME}_cleanup_old_files.sh
sudo crontab -e -u "$SVC_NAME"
```
```
*/5 * * * * /usr/local/bin/bgdsvc_sunnah658_monitor.sh
0 2 * * *   /usr/local/bin/bgdsvc_sunnah658_cleanup_old_files.sh
```

---

## Part 7 — Rotate logs

```bash
sudo mkdir -p "/var/log/$SVC_NAME"
sudo chown "$SVC_NAME:$SVC_NAME" "/var/log/$SVC_NAME"
sudo nano "/etc/logrotate.d/$SVC_NAME"
```

```
/var/log/bgdsvc_sunnah658/*.log {
    daily
    rotate 5
    compress
    missingok
    notifempty
    size 10M
    create 0640 bgdsvc_sunnah658 bgdsvc_sunnah658
}
```

```bash
sudo logrotate -f "/etc/logrotate.d/$SVC_NAME"
```

---

## Part 8 — Clean up

Cleanup is the reverse of setup — you can't unmount tmpfs or delete a user while their processes are still running.

```bash
# 1. Kill anything running
sudo pkill -u "$SVC_NAME"

# 2. Remove automation
sudo crontab -r -u "$SVC_NAME"
sudo rm -f "/etc/logrotate.d/$SVC_NAME"
sudo rm -f "/usr/local/bin/${SVC_NAME}_monitor.sh"
sudo rm -f "/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh"

# 3. Unmount storage
sudo umount "/mnt/${SVC_NAME}_tmp"
sudo rmdir "/mnt/${SVC_NAME}_tmp"

# 4. Remove logs
sudo rm -rf "/var/log/$SVC_NAME"

# 5. Remove the account
sudo userdel -r "$SVC_NAME"
```

Verify:
```bash
id "$SVC_NAME"             # should fail
mount | grep "$SVC_NAME"   # should return nothing
ps -u "$SVC_NAME"          # should be empty
```

Don't forget to revert `sshd_config` (port back to 22, remove `AllowUsers`) and restart sshd.

**Deliverable:** `04_cleanup.sh` (safe to re-run even if an earlier step failed)

---

## What I learned

- `nologin` service accounts are an easy security win
- Unbounded tmpfs or logs will eventually take a system down
- `dmesg | grep -i oom` is my new first check when a process vanishes
- Always keep a backup way into a server before hardening SSH
- Cleanup order = build order, reversed

---

## Environment

- Ubuntu (WSL2 / VM)
- bash, systemd, cron, logrotate, OpenSSH, stress-ng
