# compute.tf - EC2 and Compute Infrastructure for SA Pro
# Comprehensive setup covering Auto Scaling, Load Balancing, and advanced scenarios

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  provider    = aws.primary
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key pair for EC2 instances - Using a generated key instead of file reference
resource "tls_private_key" "lab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab_key" {
  provider   = aws.primary
  key_name   = var.key_pair_name
  public_key = tls_private_key.lab_key.public_key_openssh
  
  tags = {
    Name = "${local.common_name}-keypair"
  }
}

# Store private key in local file for use
resource "local_file" "private_key" {
  content  = tls_private_key.lab_key.private_key_pem
  filename = "${path.module}/lab-key.pem"
  file_permission = "0600"
}

# ================================================================
# IAM ROLES AND INSTANCE PROFILES
# ================================================================

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  provider = aws.primary
  name     = "${local.common_name}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  provider   = aws.primary
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_policy" {
  provider   = aws.primary
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for EC2 instances
resource "aws_iam_role_policy" "ec2_custom_policy" {
  provider = aws.primary
  name     = "${local.common_name}-ec2-custom-policy"
  role     = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.lab_bucket.arn,
          "${aws_s3_bucket.lab_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  provider = aws.primary
  name     = "${local.common_name}-ec2-profile"
  role     = aws_iam_role.ec2_role.name
}

# ================================================================
# USER DATA SCRIPTS (EMBEDDED)
# ================================================================

# Web tier user data script
locals {
  web_tier_userdata = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y httpd wget unzip

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Start and enable httpd
systemctl start httpd
systemctl enable httpd

# Create a simple web page with health check
cat << 'HTML' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>SA Pro Lab - Web Tier</title>
</head>
<body>
    <h1>SA Pro Lab - Web Tier</h1>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
    <p>Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
</body>
</html>
HTML

# Create health check endpoint
echo "OK" > /var/www/html/health

# Configure CloudWatch agent
cat << 'JSON' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "SA-Pro-Lab/WebTier",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
JSON

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
EOF
  )
  
  app_tier_userdata = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y java-11-amazon-corretto wget unzip

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create a simple Java application (Spring Boot style)
cat << 'JAVA' > App.java
import java.net.*;
import java.io.*;

public class App {
    public static void main(String[] args) throws IOException {
        ServerSocket server = new ServerSocket(8080);
        System.out.println("Application server started on port 8080");
        
        while (true) {
            Socket client = server.accept();
            new Thread(() -> {
                try {
                    BufferedReader in = new BufferedReader(new InputStreamReader(client.getInputStream()));
                    PrintWriter out = new PrintWriter(client.getOutputStream(), true);
                    
                    String request = in.readLine();
                    System.out.println("Request: " + request);
                    
                    out.println("HTTP/1.1 200 OK");
                    out.println("Content-Type: application/json");
                    out.println("");
                    out.println("{\"status\":\"OK\",\"tier\":\"application\",\"message\":\"SA Pro Lab Application Tier\"}");
                    
                    client.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }).start();
        }
    }
}
JAVA

# Compile and run the application
javac App.java

# Create systemd service
cat << 'SERVICE' > /etc/systemd/system/app.service
[Unit]
Description=SA Pro Lab Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
ExecStart=/usr/bin/java App
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

# Start application service
systemctl daemon-reload
systemctl start app
systemctl enable app

# Configure CloudWatch agent
cat << 'JSON' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "SA-Pro-Lab/AppTier",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
JSON

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
EOF
  )
  
  bastion_userdata = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y htop nmap tcpdump wireshark-cli aws-cli

# Install additional monitoring tools
yum install -y iotop nethogs iftop

# Configure SSH
echo "MaxSessions 20" >> /etc/ssh/sshd_config
echo "MaxStartups 20" >> /etc/ssh/sshd_config
systemctl restart sshd

# Create welcome message
cat << 'MOTD' > /etc/motd
===============================================
    SA Pro Lab - Bastion Host
===============================================
This is the bastion host for secure access
to private subnet resources.

Available tools:
- aws cli
- htop, iotop, nethogs, iftop
- nmap, tcpdump, wireshark-cli

Use this host to access:
- Private EC2 instances
- RDS databases
- Other private resources
===============================================
MOTD

# Install session manager plugin for enhanced connectivity
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
yum install -y session-manager-plugin.rpm
EOF
  )
}

# ================================================================
# LAUNCH TEMPLATES
# ================================================================

# Launch template for web tier
resource "aws_launch_template" "web_tier" {
  provider      = aws.primary
  name          = "${local.common_name}-web-tier"
  description   = "Launch template for web tier instances"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_types["web_tier"]
  key_name      = aws_key_pair.lab_key.key_name
  
  vpc_security_group_ids = [aws_security_group.web_tier.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  user_data = local.web_tier_userdata
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }
  
  monitoring {
    enabled = var.enable_detailed_monitoring
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${local.common_name}-web-tier"
      Tier = "web"
      Type = "auto-scaling"
    })
  }
  
  tags = {
    Name = "${local.common_name}-web-tier-template"
  }
}

# Launch template for application tier
resource "aws_launch_template" "app_tier" {
  provider      = aws.primary
  name          = "${local.common_name}-app-tier"
  description   = "Launch template for application tier instances"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_types["app_tier"]
  key_name      = aws_key_pair.lab_key.key_name
  
  vpc_security_group_ids = [aws_security_group.app_tier.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  user_data = local.app_tier_userdata
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp3"
      encrypted   = true
    }
  }
  
  monitoring {
    enabled = var.enable_detailed_monitoring
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${local.common_name}-app-tier"
      Tier = "application"
      Type = "auto-scaling"
    })
  }
  
  tags = {
    Name = "${local.common_name}-app-tier-template"
  }
}

# ================================================================
# LOAD BALANCERS
# ================================================================

# Application Load Balancer for web tier
resource "aws_lb" "web_alb" {
  count              = var.enable_compute_tier ? 1 : 0
  provider           = aws.primary
  name               = "${local.common_name}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.primary_public[*].id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${local.common_name}-web-alb"
    Type = "application-load-balancer"
  }
}

# Target group for web tier ALB
resource "aws_lb_target_group" "web_tg" {
  count    = var.enable_compute_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.primary.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "${local.common_name}-web-tg"
  }
}

# ALB Listener for web tier
resource "aws_lb_listener" "web_listener" {
  count             = var.enable_compute_tier ? 1 : 0
  provider          = aws.primary
  load_balancer_arn = aws_lb.web_alb[0].arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg[0].arn
  }
}

# Network Load Balancer for application tier (internal)
resource "aws_lb" "app_nlb" {
  count              = var.enable_compute_tier ? 1 : 0
  provider           = aws.primary
  name               = "${local.common_name}-app-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.primary_private[*].id
  
  enable_deletion_protection = false
  
  tags = {
    Name = "${local.common_name}-app-nlb"
    Type = "network-load-balancer"
  }
}

# Target group for application tier NLB
resource "aws_lb_target_group" "app_tg" {
  count    = var.enable_compute_tier ? 1 : 0
  provider = aws.primary
  name     = "${local.common_name}-app-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = aws_vpc.primary.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "8080"
    protocol            = "TCP"
    timeout             = 10
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "${local.common_name}-app-tg"
  }
}

# NLB Listener for application tier
resource "aws_lb_listener" "app_listener" {
  count             = var.enable_compute_tier ? 1 : 0
  provider          = aws.primary
  load_balancer_arn = aws_lb.app_nlb[0].arn
  port              = "8080"
  protocol          = "TCP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg[0].arn
  }
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  provider    = aws.primary
  name        = "${local.common_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "${local.common_name}-alb-sg"
  }
}

# ================================================================
# AUTO SCALING GROUPS
# ================================================================

# Auto Scaling Group for web tier
resource "aws_autoscaling_group" "web_asg" {
  count               = var.enable_compute_tier ? 1 : 0
  provider            = aws.primary
  name                = "${local.common_name}-web-asg"
  vpc_zone_identifier = aws_subnet.primary_public[*].id
  target_group_arns   = [aws_lb_target_group.web_tg[0].arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.development_mode ? 1 : 2
  max_size         = var.development_mode ? 3 : 6
  desired_capacity = var.development_mode ? 1 : 2
  
  launch_template {
    id      = aws_launch_template.web_tier.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${local.common_name}-web-asg"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Tier"
    value               = "web"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.common_tags.Environment
    propagate_at_launch = true
  }
}

# Auto Scaling Group for application tier
resource "aws_autoscaling_group" "app_asg" {
  count               = var.enable_compute_tier ? 1 : 0
  provider            = aws.primary
  name                = "${local.common_name}-app-asg"
  vpc_zone_identifier = aws_subnet.primary_private[*].id
  target_group_arns   = [aws_lb_target_group.app_tg[0].arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.development_mode ? 1 : 2
  max_size         = var.development_mode ? 3 : 6
  desired_capacity = var.development_mode ? 1 : 2
  
  launch_template {
    id      = aws_launch_template.app_tier.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "${local.common_name}-app-asg"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Tier"
    value               = "application"
    propagate_at_launch = true
  }
}

# ================================================================
# AUTO SCALING POLICIES
# ================================================================

# Scale up policy for web tier
resource "aws_autoscaling_policy" "web_scale_up" {
  count                  = var.enable_compute_tier ? 1 : 0
  provider               = aws.primary
  name                   = "${local.common_name}-web-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg[0].name
}

# Scale down policy for web tier
resource "aws_autoscaling_policy" "web_scale_down" {
  count                  = var.enable_compute_tier ? 1 : 0
  provider               = aws.primary
  name                   = "${local.common_name}-web-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg[0].name
}

# Target tracking scaling policy for app tier (SA Pro scenario)
resource "aws_autoscaling_policy" "app_target_tracking" {
  count                  = var.enable_compute_tier ? 1 : 0
  provider               = aws.primary
  name                   = "${local.common_name}-app-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app_asg[0].name
  
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# ================================================================
# BASTION HOST
# ================================================================

# Bastion host for secure access
resource "aws_instance" "bastion" {
  count                       = var.enable_compute_tier ? 1 : 0
  provider                    = aws.primary
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_types["bastion"]
  key_name                    = aws_key_pair.lab_key.key_name
  subnet_id                   = aws_subnet.primary_public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  
  user_data = local.bastion_userdata
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }
  
  tags = merge(var.common_tags, {
    Name = "${local.common_name}-bastion"
    Type = "bastion-host"
  })
}

# Security group for bastion host
resource "aws_security_group" "bastion_sg" {
  provider    = aws.primary
  name        = "${local.common_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.common_name}-bastion-sg"
  }
}

# ================================================================
# ELASTIC FILE SYSTEM (EFS)
# ================================================================

# EFS file system for shared storage
resource "aws_efs_file_system" "shared_storage" {
  count            = var.enable_compute_tier ? 1 : 0
  provider         = aws.primary
  creation_token   = "${local.common_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  encrypted        = true
  
  tags = {
    Name = "${local.common_name}-efs"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "shared_storage" {
  count           = var.enable_compute_tier ? length(aws_subnet.primary_private) : 0
  provider        = aws.primary
  file_system_id  = aws_efs_file_system.shared_storage[0].id
  subnet_id       = aws_subnet.primary_private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# Security group for EFS
resource "aws_security_group" "efs_sg" {
  provider    = aws.primary
  name        = "${local.common_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.primary.id
  
  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id, aws_security_group.web_tier.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${local.common_name}-efs-sg"
  }
}

# ================================================================
# OUTPUTS
# ================================================================

output "web_alb_dns_name" {
  description = "DNS name of the web tier load balancer"
  value       = var.enable_compute_tier ? aws_lb.web_alb[0].dns_name : "Not deployed"
}

output "app_nlb_dns_name" {
  description = "DNS name of the app tier load balancer"
  value       = var.enable_compute_tier ? aws_lb.app_nlb[0].dns_name : "Not deployed"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = var.enable_compute_tier ? aws_instance.bastion[0].public_ip : "Not deployed"
}

output "bastion_private_ip" {
  description = "Private IP of the bastion host"
  value       = var.enable_compute_tier ? aws_instance.bastion[0].private_ip : "Not deployed"
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = var.enable_compute_tier ? aws_efs_file_system.shared_storage[0].id : "Not deployed"
}

output "launch_template_ids" {
  description = "Launch template IDs"
  value = {
    web_tier = aws_launch_template.web_tier.id
    app_tier = aws_launch_template.app_tier.id
  }
}

output "auto_scaling_group_names" {
  description = "Auto Scaling Group names"
  value = var.enable_compute_tier ? {
    web_tier = aws_autoscaling_group.web_asg[0].name
    app_tier = aws_autoscaling_group.app_asg[0].name
  } : {}
}

output "private_key_path" {
  description = "Path to the generated private key file"
  value       = local_file.private_key.filename
}

output "ssh_connection_commands" {
  description = "SSH connection commands for bastion host"
  value = var.enable_compute_tier ? {
    bastion = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion[0].public_ip}"
  } : {}
}
