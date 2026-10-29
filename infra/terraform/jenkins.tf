data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-jenkins-role"
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "jenkins_deploy" {
  name = "${var.project_name}-jenkins-deploy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeEKSCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Sid      = "InspectBackendImages"
        Effect   = "Allow"
        Action   = ["ecr:DescribeImages"]
        Resource = "arn:aws:ecr:${var.aws_region}:429965676677:repository/cloud-native-backend"
      },
      {
        Sid    = "ReadDatabaseDeploymentSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:429965676677:secret:/cloud-native-devops/postgresql/admin-*",
          "arn:aws:secretsmanager:${var.aws_region}:429965676677:secret:/cloud-native-devops/postgresql/app-*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_security_group" "jenkins" {
  name_prefix = "${var.project_name}-jenkins-"
  description = "Private Jenkins host; administration through SSM"
  vpc_id      = aws_vpc.main.id

  # No inbound rules: use SSM Session Manager for administration.
  egress {
    description = "Allow outbound access through the private subnet NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

resource "aws_security_group" "eks_api_from_jenkins" {
  name_prefix = "${var.project_name}-eks-jenkins-api-"
  description = "Additional EKS cluster security group for Jenkins API access"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow EKS control plane outbound communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-jenkins-api-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_to_eks_api" {
  security_group_id            = aws_security_group.eks_api_from_jenkins.id
  referenced_security_group_id = aws_security_group.jenkins.id
  description                  = "Allow Jenkins to access the EKS Kubernetes API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/jenkins-bootstrap.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y fontconfig openjdk-21-jre unzip curl git jq ca-certificates
    # Install AWS CLI v2 using the official bundled installer.
    curl -fsSLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip

    # Install pinned kubectl and Helm versions.
    curl -fsSLo /usr/local/bin/kubectl \\
      https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl
    chmod 0755 /usr/local/bin/kubectl

    curl -fsSLo /tmp/helm.tar.gz \\
      https://get.helm.sh/helm-v3.21.4-linux-amd64.tar.gz
    tar -xzf /tmp/helm.tar.gz -C /tmp
    install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
    rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

    # Reuse an existing SSM Agent service when available.
    if systemctl list-unit-files amazon-ssm-agent.service --no-legend | grep -q '^amazon-ssm-agent.service'; then
      SSM_SERVICE=amazon-ssm-agent.service
    elif systemctl list-unit-files snap.amazon-ssm-agent.amazon-ssm-agent.service --no-legend | grep -q '^snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
      SSM_SERVICE=snap.amazon-ssm-agent.amazon-ssm-agent.service
    else
      # Install SSM Agent from the AWS regional Debian package.
      curl -fsSLo /tmp/amazon-ssm-agent.deb \
        "https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/debian_amd64/amazon-ssm-agent.deb"
      dpkg -i /tmp/amazon-ssm-agent.deb
      rm -f /tmp/amazon-ssm-agent.deb
      SSM_SERVICE=amazon-ssm-agent.service
    fi

    systemctl enable --now "$SSM_SERVICE"
    systemctl is-active --quiet "$SSM_SERVICE"

    # Install Jenkins LTS.
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \\
      -o /etc/apt/keyrings/jenkins-keyring.asc
    chmod 0644 /etc/apt/keyrings/jenkins-keyring.asc

    echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \\
      > /etc/apt/sources.list.d/jenkins.list

    apt-get update
    apt-get install -y jenkins
    systemctl enable --now jenkins
    systemctl is-active --quiet jenkins

    # Verify required tools are on PATH.
    aws --version
    kubectl version --client
    helm version --short
    jq --version
  USERDATA
  tags = {
    Name    = "${var.project_name}-jenkins"
    Project = var.project_name
    Role    = "jenkins-deployment"
  }

  depends_on = [
    aws_iam_role_policy_attachment.jenkins_ssm,
    aws_iam_role_policy.jenkins_deploy,
    aws_route.private_nat_a
  ]
}

output "jenkins_instance_id" {
  description = "EC2 instance ID for Jenkins; administer through Systems Manager"
  value       = aws_instance.jenkins.id
}
