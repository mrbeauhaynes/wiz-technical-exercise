#!/usr/bin/env bash
# ==============================================================================
# Script: reset_vulnerabilities.sh
# Purpose: Re-arms intentional vulnerabilities after testing Phase 5 remediations
#          so the environment is primed for Phase 4 attack demonstrations.
# Usage: ./reset_vulnerabilities.sh (after running: source setup_env.sh)
# ==============================================================================

set -uo pipefail

if [ -z "${BUCKET_NAME:-}" ] || [ -z "${DB_SG:-}" ]; then
  echo "[!] ERROR: Environment variables missing. Run 'source setup_env.sh' first."
  exit 1
fi

echo "=============================================================================="
echo " RESETTING ENVIRONMENT TO INTENTIONALLY VULNERABLE STATE"
echo "=============================================================================="

# 1. Re-open S3 Bucket (Disable Block Public Access & Re-apply Public Policy)
echo "[1/3] Re-arming S3 public data exposure on '$BUCKET_NAME'..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

cat << POLICY_EOF > /tmp/s3_public_policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    }
  ]
}
POLICY_EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/s3_public_policy.json
rm -f /tmp/s3_public_policy.json

# Quick check
if aws s3 ls "s3://$BUCKET_NAME" --no-sign-request >/dev/null 2>&1; then
  echo "      Status: OK -> S3 bucket is publicly readable again."
else
  echo "      Status: WARNING -> Public read verification failed."
fi
echo ""

# 2. Re-open Port 22 on MongoDB Security Group
echo "[2/3] Re-opening Port 22 (0.0.0.0/0) on Security Group '$DB_SG'..."

aws ec2 authorize-security-group-ingress \
  --group-id "$DB_SG" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 2>/dev/null || echo "      Port 22 ingress rule already present."

echo "      Status: OK -> Port 22 open to 0.0.0.0/0."
echo ""

# 3. Re-create the Overprivileged ClusterRoleBinding
echo "[3/3] Re-binding 'cluster-admin' to webapp-overprivileged-sa..."

kubectl create clusterrolebinding webapp-admin-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=wiz-app:webapp-overprivileged-sa 2>/dev/null || echo "      Binding already present."

CHECK=$(kubectl auth can-i --as=system:serviceaccount:wiz-app:webapp-overprivileged-sa '*' '*')
echo "      Status: OK -> Can webapp-overprivileged-sa perform '*' on '*'? $CHECK"

echo ""
echo "[5.4] Disabling IMDSv2 (HttpTokens=required) on MongoDB EC2 Host ($MONGO_IP):"
MONGO_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=$MONGO_IP" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

aws ec2 modify-instance-metadata-options \
  --instance-id "$MONGO_INSTANCE_ID" \
  --http-tokens optional \
  --http-endpoint enabled > /dev/null
echo ""
echo "Verifying IMDSv2 enforcement on $MONGO_INSTANCE_ID:"
  aws ec2 describe-instances \
    --instance-ids "$MONGO_INSTANCE_ID" \
    --query "Reservations[0].Instances[0].[InstanceId,MetadataOptions.HttpTokens,MetadataOptions.HttpEndpoint]" \
    --output table
else
  echo "MongoDB EC2 instance ID could not be resolved."
fi
echo ""
echo "=============================================================================="
echo " ENVIRONMENT IS PRIMED AND VULNERABLE FOR DEMO / REHEARSAL"
echo "=============================================================================="
