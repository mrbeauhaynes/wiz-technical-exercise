# EC2 Security Group: Open SSH to Internet, MongoDB locked to Private Subnets
resource "aws_security_group" "mongodb_vm" {
  name        = "${var.environment}-mongodb-sg"
  description = "Vulnerable SG: Exposed SSH and restricted MongoDB"
  vpc_id      = aws_vpc.main.id

  # Intentional Vulnerability: Public SSH (0.0.0.0/0)
  ingress {
    description = "Public SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Requirement: MongoDB restricted strictly to Kubernetes private network
  ingress {
    description = "MongoDB from Private Subnets"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_1.cidr_block, aws_subnet.private_2.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-mongodb-sg"
  }
}

# Public ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "ALB public HTTP ingress"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-alb-sg"
  }
}