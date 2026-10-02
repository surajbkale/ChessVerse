#!/bin/bash
# ChessVerse Backend — EC2 Boot Script
# Fetches secrets from Secrets Manager, starts backend Docker container.
set -euxo pipefail

REGION="${aws_region}"
SECRET_ARN="${secret_arn}"
ECR_BACKEND="${ecr_backend_url}"
IMAGE_TAG_SSM_PARAM="${image_tag_ssm_param}"
LOG_GROUP="${log_group}"
ENV="${environment}"

# Read the deployed image tag from SSM at boot.
# The deploy workflow writes the exact git SHA here, so auto-scaled
# instances always start the same image as the last successful deploy.
# B4 fix: fall back to "latest" if the param doesn't exist yet (first apply before any deploy).
IMAGE_TAG=$(aws ssm get-parameter --name "$IMAGE_TAG_SSM_PARAM" \
  --region "$REGION" --query Parameter.Value --output text 2>/dev/null || echo "latest")

# ── Install dependencies ──────────────────────────────────────────────────────
apt-get update -y
apt-get install -y docker.io awscli jq curl unzip

systemctl enable docker && systemctl start docker
usermod -aG docker ubuntu

# Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# CloudWatch Agent
curl -fsSL https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb \
  -o /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb

# ── Fetch app secrets and write .env ─────────────────────────────────────────
mkdir -p /opt/chessverse && chmod 700 /opt/chessverse

aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" --region "$REGION" \
  --query SecretString --output text \
  | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /opt/chessverse/.env
chmod 600 /opt/chessverse/.env

# ── CloudWatch agent config ───────────────────────────────────────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CW_EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/**/*-json.log",
            "log_group_name": "$LOG_GROUP",
            "log_stream_name": "{instance_id}/backend",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S",
            "auto_removal": true
          }
        ]
      }
    }
  }
}
CW_EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# ── Authenticate with ECR and start container ─────────────────────────────────
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$(echo $ECR_BACKEND | cut -d'/' -f1)"

cat > /opt/chessverse/docker-compose.yml << DC_EOF
services:
  backend:
    image: $ECR_BACKEND:$IMAGE_TAG
    restart: always
    ports:
      - "3000:3000"
    env_file: /opt/chessverse/.env
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"
DC_EOF

# Tag this instance for SSM Run Command targeting
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --region "$REGION" --resources "$INSTANCE_ID" \
  --tags "Key=ChessverseService,Value=backend" "Key=Environment,Value=$ENV"

cd /opt/chessverse
docker compose pull && docker compose up -d
echo "ChessVerse backend started on $(date)"
