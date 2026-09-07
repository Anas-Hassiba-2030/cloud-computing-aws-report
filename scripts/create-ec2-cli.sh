#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Path 2 of 3: create the same VM with the AWS CLI.
#
# Same result as the console walkthrough (report.html section 5.1) and the
# Terraform config in ../terraform. The difference worth noticing: this script
# CREATES resources but does not TRACK them - if you run it twice you get two
# of everything. That is the argument for infrastructure as code, made by
# running the same job both ways.
#
# Prerequisites:  aws configure    (an IAM user with EC2 permissions)
# Run:            bash scripts/create-ec2-cli.sh
# Tear down:      bash scripts/create-ec2-cli.sh --destroy
# ---------------------------------------------------------------------------
set -euo pipefail

REGION="${REGION:-us-east-1}"
NAME="${NAME:-cloud-project-cli}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t4g.micro}"
KEY_NAME="$NAME-key"
SG_NAME="$NAME-sg"

# --------------------------------------------------------------------------
# Tear-down path first, so it is easy to find when the bill is running.
# --------------------------------------------------------------------------
if [[ "${1:-}" == "--destroy" ]]; then
  IDS=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=pending,running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
  if [[ -n "$IDS" ]]; then
    echo "Terminating: $IDS"
    aws ec2 terminate-instances --region "$REGION" --instance-ids $IDS >/dev/null
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids $IDS
  fi
  aws ec2 delete-key-pair --region "$REGION" --key-name "$KEY_NAME" 2>/dev/null || true
  aws ec2 delete-security-group --region "$REGION" --group-name "$SG_NAME" 2>/dev/null || true
  echo "Done. Nothing left billing."
  exit 0
fi

# --------------------------------------------------------------------------
# 1. Which image? Ask SSM for the current Amazon Linux 2023 arm64 AMI rather
#    than pasting an ami-xxxx from a blog post that expired months ago.
# --------------------------------------------------------------------------
AMI_ID=$(aws ssm get-parameters --region "$REGION" \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query 'Parameters[0].Value' --output text)
echo "AMI: $AMI_ID"

# --------------------------------------------------------------------------
# 2. Key pair. AWS generates it and hands back the private key ONCE. If you
#    lose this file you cannot get into the instance again - there is no
#    recovery, only a rebuild.
# --------------------------------------------------------------------------
if ! aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" >/dev/null 2>&1; then
  aws ec2 create-key-pair --region "$REGION" --key-name "$KEY_NAME" \
    --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
  chmod 400 "$KEY_NAME.pem"     # ssh refuses to use a world-readable key
  echo "Private key written to $KEY_NAME.pem (chmod 400). Do not commit it."
fi

# --------------------------------------------------------------------------
# 3. Security group: SSH from this machine only, HTTP from anywhere.
# --------------------------------------------------------------------------
MY_IP="$(curl -s https://checkip.amazonaws.com)/32"
echo "Your address: $MY_IP"

SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --group-names "$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)

if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
  SG_ID=$(aws ec2 create-security-group --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "HTTP from anywhere, SSH from one address" \
    --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MY_IP,Description='SSH from me'}]" >/dev/null
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description='public web'}]" >/dev/null
fi
echo "Security group: $SG_ID"

# --------------------------------------------------------------------------
# 4. Launch. --metadata-options enforces IMDSv2; --block-device-mappings sets
#    an encrypted 20 GiB gp3 root volume that dies with the instance.
# --------------------------------------------------------------------------
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --user-data "file://$(dirname "$0")/user-data.sh" \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=1" \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":20,"VolumeType":"gp3","Encrypted":true,"DeleteOnTermination":true}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=Project,Value=cloud-computing-report}]" \
  --query 'Instances[0].InstanceId' --output text)

echo "Launched $INSTANCE_ID - waiting for it to reach 'running'..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

cat <<EOF

  Instance : $INSTANCE_ID
  Address  : $PUBLIC_IP
  Web      : http://$PUBLIC_IP/        (give user-data ~60s to finish installing nginx)
  SSH      : ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP

  When finished:  bash scripts/create-ec2-cli.sh --destroy
  Stopping is not enough - a stopped instance still bills for its EBS volume.
EOF
