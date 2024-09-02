provider "aws" {
  region = "us-west-2"  # Update to your desired region
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "eks_subnet" {
  count = 3
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.${count.index + 1}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-${count.index}"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn  = aws_iam_role.eks_role.arn
  version   = "1.24"  # Update to your desired Kubernetes version

  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
    endpoint_public_access = true
  }

  tags = {
    Name = "my-eks-cluster"
  }
}

resource "aws_iam_role" "eks_role" {
  name = "eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_role_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_eks_node_group" "fargate_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "fargate-node-group"
  node_role_arn   = aws_iam_role.fargate_node_role.arn
  subnets         = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  tags = {
    Name = "fargate-node-group"
  }
}

resource "aws_iam_role" "fargate_node_role" {
  name = "fargate-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_node_policy" {
  role       = aws_iam_role.fargate_node_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "fargate_cni_policy" {
  role       = aws_iam_role.fargate_node_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
}

resource "aws_iam_role_policy_attachment" "fargate_container_registry" {
  role       = aws_iam_role.fargate_node_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  name         = "my-fargate-profile"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids   = aws_subnet.eks_subnet[*].id

  selector {
    namespace = "default"
  }
}

resource "aws_iam_role" "fargate_pod_execution_role" {
  name = "fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_policy" {
  role       = aws_iam_role.fargate_pod_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}
