#!/bin/bash

SVC="${SVC_NAME:-bgdsvc_sunnah658}"
TARGET_DIR="/mnt/${SVC}_tmp"

case "$1" in
    --disk)
        echo "Filling tmpfs disk..."
        for i in $(seq 1 30); do
            dd if=/dev/urandom of="$TARGET_DIR/file_$i.dat" bs=10M count=1 2>/dev/null || break
            df -h "$TARGET_DIR"
        done
        ;;
    --cpu)
        echo "Running CPU stress..."
        sudo -u "$SVC" stress-ng --cpu 2 --temp-path /tmp --timeout 30s
        ;;
    --mem)
        echo "Running Memory stress..."
        sudo -u "$SVC" stress-ng --vm 1 --vm-bytes 200M --temp-path /tmp --timeout 30s
        ;;
    --all)
        echo "Running All stress tests combined..."
        for i in $(seq 1 30); do
            dd if=/dev/urandom of="$TARGET_DIR/file_$i.dat" bs=10M count=1 2>/dev/null || break
        done
        sudo -u "$SVC" stress-ng --cpu 2 --vm 1 --vm-bytes 200M --temp-path /tmp --timeout 30s
        ;;
    *)
        echo "Usage: $0 {--cpu|--mem|--disk|--all}"
        exit 1
        ;;
esac
