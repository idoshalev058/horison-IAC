##############################################################
# EKS Cluster Infrastructure
##############################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "sandbox-eks-cluster"
  cluster_version = "1.35"

  cluster_endpoint_public_access = true
  
  # Pulling IDs dynamically from data.tf
  vpc_id                 = data.aws_vpc.existing_vpc.id
  subnet_ids             = data.aws_subnets.existing_subnets.ids
  node_security_group_id = data.aws_security_group.existing_sg.id

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }
  
  cluster_compute_config = {
    enabled    = true
    node_pools = ["system"]
  }

  enable_cluster_creator_admin_permissions = true
}

##############################################################
# Spot NodePool for Karpenter
##############################################################
resource "kubectl_manifest" "spot_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: budget-spot-pool
    spec:
      template:
        spec:
          nodeClassRef:
            group: eks.amazonaws.com
            kind: NodeClass
            name: default
          requirements:
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot"]
            - key: "node.kubernetes.io/instance-type"
              operator: In
              values: ["t3.medium", "t3.small", "t3.large"] 
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
      limits:
        cpu: "4"
        memory: "8Gi"
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [module.eks]
}