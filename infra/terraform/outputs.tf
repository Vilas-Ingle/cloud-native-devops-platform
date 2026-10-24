
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "eks_cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "The name of the EKS cluster"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The EKS Kubernetes API endpoint"
}

output "eks_node_group_name" {
  value       = aws_eks_node_group.main.node_group_name
  description = "The name of the EKS node group"
}
