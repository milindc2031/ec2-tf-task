#!/bin/bash
# Install NFS client for mounting EFS
yum install -y amazon-efs-utils

# Create directory for mounting
mkdir -p /data/test

# Mount EFS filesystem
mount -t efs ${efs_id}:/ /data/test

# Set permissions for the mount
chmod 777 /data/test
