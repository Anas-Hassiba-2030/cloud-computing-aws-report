#!/bin/bash
# ---------------------------------------------------------------------------
# EC2 user data: the first thing the VM runs, as root, on its first boot.
#
# This is what turns "a blank Linux box" into "a web server" without anyone
# logging in. It is the bootstrap step in Figure 5 (instance lifecycle) of the
# report: pending -> [user data runs] -> running and already serving traffic.
#
# Debug it on the instance with:   sudo cat /var/log/cloud-init-output.log
# ---------------------------------------------------------------------------
set -euxo pipefail

dnf -y update
dnf -y install nginx

# Ask the instance metadata service who we are. IMDSv2 is token-based: you PUT
# for a token first, then GET with it. IMDSv1's plain GET is disabled on this
# instance on purpose (see metadata_options in terraform/main.tf).
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)
ITYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type)

cat > /usr/share/nginx/html/index.html <<HTML
<!doctype html>
<meta charset="utf-8">
<title>Cloud Computing project - EC2 instance</title>
<style>
  body{font:16px/1.6 system-ui,sans-serif;max-width:34rem;margin:8vh auto;padding:0 1rem;color:#0b0b0b}
  h1{font-size:1.4rem} dt{color:#52514e;font-size:.85rem} dd{margin:0 0 .8rem;font-weight:600}
</style>
<h1>This page is served by a virtual machine on Amazon EC2.</h1>
<p>It was configured entirely by the user-data script, with nobody logging in.</p>
<dl>
  <dt>Instance ID</dt><dd>$IID</dd>
  <dt>Instance type</dt><dd>$ITYPE</dd>
  <dt>Availability Zone</dt><dd>$AZ</dd>
  <dt>Booted at</dt><dd>$(date -u '+%Y-%m-%d %H:%M:%S UTC')</dd>
</dl>
HTML

systemctl enable --now nginx
