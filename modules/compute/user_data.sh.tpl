#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

apt-get update -y
apt-get install -y docker.io jq snapd unzip curl
systemctl enable --now docker

# Установка AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region us-east-1 \
  --query SecretString --output text | jq -r .password)

docker run -d -p 3000:3000 \
  -e DB_HOST="${db_host}" \
  -e DB_PORT="5432" \
  -e DB_USER="${db_user}" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_NAME="${db_name}" \
  -e DB_SSL="true" \
  -e AWS_REGION="us-east-1" \
  -e S3_BUCKET_NAME="${bucket}" \
  --restart always \
  ${app_image}
