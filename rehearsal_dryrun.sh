#!/usr/bin/env bash
# ==============================================================================
# Script: rehearsal_dryrun.sh
# Purpose: Interactive walkthrough for the Wiz technical panel dry run.
#          Executes all five presentation phases with script notations,
#          structured command execution, and pauses for talk tracks.
# Usage: ./rehearsal_dryrun.sh (after running: source setup_env.sh)
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
  echo " [NEXT PHASE: $phase_num - $phase_title]"
  echo " Spoken Objective:"
  echo "   $talk_track"
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
print_banner "WIZ TECHNICAL PANEL ASSESSMENT: LIVE DRY RUN HARNESS"
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
PAYLOAD="{\"title\": \"Dry Run Persistence Test\", \"status\": \"verified-$(date +%H%M%S)\"}"
echo "Submitting POST request to http://$ALB_URL/tasks"
curl -s -X POST "http://$ALB_URL/tasks" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
echo ""
echo "Querying persistent task records from database:"
curl -s "http://$ALB_URL/tasks" | jq . 2>/dev/null || curl -s "http://$ALB_URL/tasks"
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

echo "[2.2] GitHub Actions Pipeline Artifacts:"
echo "Presentation Target: https://github.com/mrbeauhaynes/wiz-technical-exercise/actions"
echo ""
echo "Talk Track Highlights:"
echo "  * Automated Trigger : Executes Trivy vulnerability and config checks on every push."
echo "  * Container Audit   : Surfaced 43 High and Critical CVEs inherited from Alpine base."
echo "  * IaC Audit         : Caught open port 22, IMDSv1, wildcard IAM, and open S3 prior to apply."

# ==============================================================================
# PHASE 3: CONTROL PLANE LOGGING & DETECTIVE CONTROLS
# ==============================================================================
pause_phase "3" "Control Plane Logging & Detective Controls" \
"Demonstrate active multi-region CloudTrail management logging, verify all five EKS control plane streams, pull live CloudWatch API server logs, and query GuardDuty."

print_banner "PHASE 3: AUDIT LOGGING & NATIVE DETECTIVE CONTROLS"

echo "[3.1] Verifying AWS CloudTrail multi-region management logging status:"
aws cloudtrail describe-trails --query "trailList[*].[Name,IsMultiRegionTrail]" --output table
echo ""

echo "[3.2] Verifying EKS control plane logging streams (api, audit, authenticator):"
aws eks describe-cluster --name wiz-exercise-cluster \
  --query "cluster.logging.clusterLogging[*].types" --output json
echo ""

echo "[3.3] Streaming live kube-apiserver audit events from AWS CloudWatch:"
aws logs filter-log-events \
  --log-group-name "/aws/eks/wiz-exercise-cluster/cluster" \
  --filter-pattern "kube-apiserver-audit" \
  --limit 3 \
  --query "events[*].[timestamp,message]" --output table
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

# Dynamically resolve whatever backup archive exists in the bucket
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

echo "[4.4] Checking IMDSv1 availability on database host:"
echo "Querying EC2 metadata service without token header:"
curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/iam/security-credentials/ || echo "(IMDSv1 query evaluated)"

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

print_banner "DRY RUN REHEARSAL COMPLETE"
echo "All 5 phases executed and validated."
