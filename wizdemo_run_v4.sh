#!/usr/bin/env bash
# ==============================================================================
# Script: wizdemo_runv4.sh
# Purpose: Interactive walkthrough for the Wiz technical panel demonstration.
#          Executes all five presentation phases with clean banner notations,
#          structured command execution, and pauses for talk tracks.
# Usage: ./wizdemo_run.sh (after running: source setup_env.sh)
# ==============================================================================

set -uo pipefail

# Section divider helper
print_banner() {
  local title="$1"
  echo ""
  echo "=============================================================================="
  echo " $title"
  echo "=============================================================================="
  echo ""
}

# Interactive pause helper
pause_phase() {
  local phase_num="$1"
  local phase_title="$2"
  local talk_track="$3"

  echo ""
  echo "------------------------------------------------------------------------------"
  echo " [NEXT PHASE $phase_num: $phase_title]"
  echo "------------------------------------------------------------------------------"
  read -rp ">> Press [ENTER] to execute commands for this phase (or Ctrl+C to exit)... "
  echo ""
}

# Pre-flight environment check
if [ -z "${ALB_URL:-}" ] || [ -z "${BUCKET_NAME:-}" ] || [ -z "${DB_SG:-}" ]; then
  echo "[!] ERROR: Environment variables missing. Run 'source setup_env.sh' first."
  exit 1
fi

clear
print_banner "WIZ TECHNICAL PANEL ASSESSMENT: LIVE DEMONSTRATION"
echo " Candidate       : Beau Haynes Sr."
echo " Cloud Platform  : AWS (us-east-1)"
echo " Cluster Target  : wiz-exercise-cluster (EKS)"
echo " Load Balancer   : $ALB_URL"
echo " Storage Target  : $BUCKET_NAME"
echo " Database Target : $MONGO_IP (SG: $DB_SG)"
echo " Kubeconfig      : $KUBECONFIG"

# ==============================================================================
# PHASE 1: ARCHITECTURE & TOPOLOGY OVERVIEW
# ==============================================================================
pause_phase "1" "Architecture & Topology Overview" \
"Showcase the multi-tier deployment across EKS and EC2, verify container health, prove the baked verification marker, and confirm read/write persistence into MongoDB."

print_banner "PHASE 1: WORKLOAD HEALTH, NODE DISTRIBUTION & MARKER VERIFICATION"

echo "[1.1] Querying EKS Managed Node Group topology:"
kubectl get nodes -o wide
echo ""

echo "[1.2] Verifying application pod status in namespace 'wiz-app':"
kubectl get pods -n wiz-app -o wide
echo ""

echo "[1.3] Inspecting baked candidate verification file (/app/wizexercise.txt):"
kubectl exec -n wiz-app deployment/webapp-deployment -- cat /app/wizexercise.txt
echo ""

echo "[1.4] Testing end-to-end task persistence through ALB into MongoDB:"
DEMO_TITLE="Live Architecture Demo Task - $(date +%H%M%S)"
echo "Submitting POST request to http://$ALB_URL/task with title: '$DEMO_TITLE'"
curl -s -X POST "http://$ALB_URL/task" -d "title=$DEMO_TITLE" > /dev/null
echo ""
echo "Querying persistent task records rendered from MongoDB:"
curl -s "http://$ALB_URL/" | grep -o "<li>$DEMO_TITLE.*</li>" | head -n 1
echo ""

# ==============================================================================
# PHASE 2: SHIFT-LEFT DEVSECOPS PIPELINE
# ==============================================================================
pause_phase "2" "Shift-Left DevSecOps Pipeline Walkthrough" \
"Walk through the GitHub repository, highlighting version control of all IaC manifests, and demonstrate automated Trivy gating in the GitHub Actions summary tab."

print_banner "PHASE 2: SHIFT-LEFT DEVSECOPS & AUTOMATED TRIVY GATING"

echo "[2.1] Verifying tracked repository manifests in local workspace:"
cd /home/cloudshell-user/wizexercise
git status -s
echo ""
echo "Version-controlled infrastructure and deployment manifests:"
git ls-files "*.tf" "k8s-deployment.yaml" "Dockerfile" ".github/workflows/*"
echo ""

# ==============================================================================
# PHASE 3: CONTROL PLANE LOGGING & DETECTIVE CONTROLS
# ==============================================================================
pause_phase "3" "Control Plane Logging & Detective Controls" \
"Prove active multi-region CloudTrail management logging, confirm EKS control plane streams (api, audit, authenticator), stream live IAM-to-RBAC and API audit records, and verify GuardDuty."

print_banner "PHASE 3: AUDIT LOGGING & NATIVE DETECTIVE CONTROLS"

echo "[3.1] Verifying AWS CloudTrail multi-region management logging status:"
aws cloudtrail describe-trails \
  --query "trailList[*].[Name,IsMultiRegionTrail]" \
  --output table
echo ""

echo "[3.2] Verifying EKS control plane logging streams (api, audit, authenticator):"
aws eks describe-cluster --name wiz-exercise-cluster \
  --query "cluster.logging.clusterLogging[?enabled==\`true\`].types" \
  --output json
echo ""

echo "[3.3] Streaming live EKS control plane telemetry from AWS CloudWatch:"
AUTH_STREAM=$(aws logs describe-log-streams \
  --log-group-name "/aws/eks/wiz-exercise-cluster/cluster" \
  --log-stream-name-prefix "authenticator" \
  --limit 1 \
  --query "logStreams[0].logStreamName" \
  --output text 2>/dev/null || echo "")

AUDIT_STREAM=$(aws logs describe-log-streams \
  --log-group-name "/aws/eks/wiz-exercise-cluster/cluster" \
  --log-stream-name-prefix "kube-apiserver-audit" \
  --limit 1 \
  --query "logStreams[0].logStreamName" \
  --output text 2>/dev/null || echo "")

if [ -n "$AUTH_STREAM" ] && [ "$AUTH_STREAM" != "None" ]; then
  echo "--> IAM Authenticator Stream ($AUTH_STREAM):"
  aws logs get-log-events \
    --log-group-name "/aws/eks/wiz-exercise-cluster/cluster" \
    --log-stream-name "$AUTH_STREAM" \
    --limit 2 \
    --query "events[*].[timestamp,message]" \
    --output table
fi

if [ -n "$AUDIT_STREAM" ] && [ "$AUDIT_STREAM" != "None" ]; then
  echo "--> Kubernetes API Audit Stream ($AUDIT_STREAM):"
  aws logs get-log-events \
    --log-group-name "/aws/eks/wiz-exercise-cluster/cluster" \
    --log-stream-name "$AUDIT_STREAM" \
    --limit 2 \
    --query "events[*].[timestamp,message]" \
    --output table
fi
echo ""

echo "[3.4] Querying active AWS GuardDuty detector findings:"
DETECTOR_ID=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text 2>/dev/null || echo "")
if [ -n "$DETECTOR_ID" ] && [ "$DETECTOR_ID" != "None" ]; then
  echo "Active GuardDuty Detector: $DETECTOR_ID"
  aws guardduty list-findings --detector-id "$DETECTOR_ID" --max-items 5 --output table
else
  echo "GuardDuty detector not active or telemetry aggregating."
fi

# ==============================================================================
# PHASE 4: ATTACK PATH DEMONSTRATION
# ==============================================================================
pause_phase "4" "Attack Path Demonstration" \
"Demonstrate the practical exploitability of the architecture: unauthenticated S3 database dump extraction, cluster-admin service account privileges, and IMDSv1 exposure."

print_banner "PHASE 4: LIVE ATTACK PATH VALIDATION"

echo "[4.1] Public S3 Bucket Enumeration (Zero AWS Credentials):"
echo "Executing: aws s3 ls s3://$BUCKET_NAME --no-sign-request"
aws s3 ls "s3://$BUCKET_NAME" --no-sign-request
echo ""

# Dynamically resolve backup archive in bucket
BACKUP_ARCHIVE=$(aws s3 ls "s3://$BUCKET_NAME" --no-sign-request | awk '{print $4}' | grep '\.tar\.gz' | head -n 1)
if [ -z "$BACKUP_ARCHIVE" ]; then
  BACKUP_ARCHIVE=$(aws s3 ls "s3://$BUCKET_NAME" --no-sign-request | awk '{print $4}' | head -n 1)
fi

echo "[4.2] Exfiltrating database backup tarball ($BACKUP_ARCHIVE) anonymously:"
aws s3 cp "s3://$BUCKET_NAME/$BACKUP_ARCHIVE" /tmp/stolen-backup.tar.gz --no-sign-request
ls -lh /tmp/stolen-backup.tar.gz
echo ""

echo "[4.3] Verifying cluster-admin RBAC rights on webapp service account:"
echo "Executing: kubectl auth can-i --as=system:serviceaccount:wiz-app:webapp-overprivileged-sa '*' '*'"
kubectl auth can-i --as=system:serviceaccount:wiz-app:webapp-overprivileged-sa '*' '*'
echo ""

echo "[4.4] Verifying IMDSv1 availability on MongoDB EC2 host ($MONGO_IP):"
aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=$MONGO_IP" \
  --query "Reservations[0].Instances[0].[InstanceId,MetadataOptions.HttpTokens,MetadataOptions.HttpEndpoint]" \
  --output table
echo ""

# ==============================================================================
# PHASE 5: LIVE REMEDIATION & PREVENTATIVE CONTROLS
# ==============================================================================
pause_phase "5" "Live Preventative Guardrails & Quick Remediation" \
"Execute live, single-command remediations: apply S3 Block Public Access to kill the data leak, revoke SSH 0.0.0.0/0 on the DB host, and demote the cluster-admin service account."

print_banner "PHASE 5: LIVE REMEDIATION & PREVENTATIVE GUARDRAILS"

echo "[5.1] Remediating Public S3 Bucket Exposure:"
echo "Deleting anonymous bucket policy..."
aws s3api delete-bucket-policy --bucket "$BUCKET_NAME" 2>/dev/null || true

echo "Applying S3 Block Public Access preventative controls..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Verifying anonymous exfiltration is blocked:"
if aws s3 ls "s3://$BUCKET_NAME" --no-sign-request 2>&1 | grep -q 'AccessDenied'; then
  echo "  [SUCCESS] Anonymous requests rejected with Access Denied."
else
  aws s3 ls "s3://$BUCKET_NAME" --no-sign-request || true
fi
echo ""

echo "[5.2] Revoking Public SSH Port 22 Ingress on MongoDB Security Group ($DB_SG):"
aws ec2 revoke-security-group-ingress \
  --group-id "$DB_SG" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 2>/dev/null || echo "Rule already revoked."

echo "Verifying port 22 is eliminated from security group permissions:"
aws ec2 describe-security-groups \
  --group-ids "$DB_SG" \
  --query "SecurityGroups[0].IpPermissions[?ToPort==\`22\`]" --output json
echo ""

echo "[5.3] Demoting Overprivileged Kubernetes ClusterRoleBinding:"
kubectl delete clusterrolebinding webapp-admin-binding --ignore-not-found=true
echo "Verifying webapp-overprivileged-sa permissions:"
kubectl auth can-i --as=system:serviceaccount:wiz-app:webapp-overprivileged-sa '*' '*'

echo "[5.4] Enforcing IMDSv2 (HttpTokens=required) on MongoDB EC2 Host ($MONGO_IP):"
MONGO_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=private-ip-address,Values=$MONGO_IP" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ -n "$MONGO_INSTANCE_ID" ] && [ "$MONGO_INSTANCE_ID" != "None" ]; then
  aws ec2 modify-instance-metadata-options \
    --instance-id "$MONGO_INSTANCE_ID" \
    --http-tokens required \
    --http-endpoint enabled > /dev/null

  echo "Verifying IMDSv2 enforcement on $MONGO_INSTANCE_ID:"
  aws ec2 describe-instances \
    --instance-ids "$MONGO_INSTANCE_ID" \
    --query "Reservations[0].Instances[0].[InstanceId,MetadataOptions.HttpTokens,MetadataOptions.HttpEndpoint]" \
    --output table
else
  echo "MongoDB EC2 instance ID could not be resolved."
fi
echo ""

print_banner "DRY RUN REHEARSAL COMPLETE"
echo "All 5 phases executed and validated."
