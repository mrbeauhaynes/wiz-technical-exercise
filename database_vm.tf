# Overprivileged IAM Role for the Database VM
resource "aws_iam_role" "ec2_overprivileged_role" {
  name = "${var.environment}-ec2-db-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Overly permissive policy: Allows creating/modifying VMs and reading/writing S3
resource "aws_iam_policy" "overprivileged_policy" {
  name        = "${var.environment}-overprivileged-policy"
  description = "Overly permissive CSP permissions for Wiz exercise"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ComputeAdminAccess"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Sid      = "S3BackupAccess"
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.db_backups.arn,
          "${aws_s3_bucket.db_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_overprivileged" {
  role       = aws_iam_role.ec2_overprivileged_role.name
  policy_arn = aws_iam_policy.overprivileged_policy.arn
}

resource "aws_iam_instance_profile" "db_profile" {
  name = "${var.environment}-db-instance-profile"
  role = aws_iam_role.ec2_overprivileged_role.name
}

# Outdated OS: Ubuntu 20.04 LTS AMI (Focal Fossa - released > 1 year ago)
data "aws_ami" "ubuntu_outdated" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance: Public Subnet, Open Port 22, Outdated MongoDB 5.0
resource "aws_instance" "mongodb" {
  ami                         = data.aws_ami.ubuntu_outdated.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.mongodb_vm.id]
  iam_instance_profile        = aws_iam_instance_profile.db_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Install Prereqs & Outdated MongoDB 5.0 (Released 2021)
              apt-get update -y
              apt-get install -y gnupg curl awscli
              curl -fsSL https://pgp.mongodb.com/server-5.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-5.0.gpg
              echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-5.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
              apt-get update -y
              apt-get install -y mongodb-org=5.0.28 mongodb-org-server=5.0.28 mongodb-org-shell=5.0.28 mongodb-org-mongos=5.0.28 mongodb-org-tools=5.0.28

              # Bind to all interfaces for network connectivity
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              systemctl enable mongod
              systemctl start mongod

              # Wait for Mongo startup
              sleep 10

              # Create Admin and Application Users
              mongosh admin --eval 'db.createUser({user: "${var.db_username}", pwd: "${var.db_password}", roles: [{role: "root", db: "admin"}]})'
              mongosh admin -u "${var.db_username}" -p "${var.db_password}" --eval 'db.getSiblingDB("tododb").createUser({user: "appuser", pwd: "apppassword", roles: [{role: "readWrite", db: "tododb"}]})'

              # Enable Authorization in mongod.conf
              echo -e "security:\n  authorization: enabled" >> /etc/mongod.conf
              systemctl restart mongod

              # Automated Daily Backup Cron Job writing to S3 Bucket
              cat << 'CRON' > /usr/local/bin/backup_mongo.sh
              #!/bin/bash
              TIMESTAMP=\$(date +\%Y\%m\%d_\%H\%M\%S)
              BACKUP_DIR="/tmp/mongodump_\$TIMESTAMP"
              mongodump --username ${var.db_username} --password ${var.db_password} --authenticationDatabase admin --out \$BACKUP_DIR
              tar -czf \$BACKUP_DIR.tar.gz -C /tmp mongodump_\$TIMESTAMP
              aws s3 cp \$BACKUP_DIR.tar.gz s3://${aws_s3_bucket.db_backups.id}/backups/mongodump_\$TIMESTAMP.tar.gz
              rm -rf \$BACKUP_DIR \$BACKUP_DIR.tar.gz
              CRON

              chmod +x /usr/local/bin/backup_mongo.sh
              # Run immediately once to populate the bucket, then schedule daily
              /usr/local/bin/backup_mongo.sh || true
              echo "0 2 * * * root /usr/local/bin/backup_mongo.sh" > /etc/cron.d/mongo_backup
              EOF

  tags = {
    Name = "${var.environment}-mongodb-vm"
  }
}