data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "midnight_node_role" {
  name = "midnight-node-role"

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

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.midnight_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "midnight_node_profile" {
  name = "midnight-node-profile"
  role = aws_iam_role.midnight_node_role.name
}

resource "aws_instance" "midnight_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = data.aws_subnets.available.ids[0]

  vpc_security_group_ids = [aws_security_group.midnight_node_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.midnight_node_profile.name

  root_block_device {
    volume_size           = 500
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  user_data = templatefile("../../install_midnight_archive_node.sh", {
    NETWORK_ENV = var.target_network
  })

  tags = {
    Name = "midnight-archive-node"
  }
}
