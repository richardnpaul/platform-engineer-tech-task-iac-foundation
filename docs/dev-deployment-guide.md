# Dev Environment Deployment Guide

This guide walks through deploying the shared VPC and two EKS clusters (management + applications) in the dev account.

## Architecture Overview

**Shared Infrastructure ($48/month):**
- VPC with public/private subnets across 2 AZs
- Single NAT Gateway: $32/month
- Shared Application Load Balancer: $16/month
- Two target groups (mgmt-cluster, apps-cluster)

**EKS Clusters ($146/month):**
- Management cluster (ArgoCD): $73/month
- Application cluster (workloads): $73/month
- Both use Fargate (400 vCPU-hours FREE/month)

**Total: ~$194/month**

## Prerequisites

1. **Environment variables:**
   ```bash
   export TG_CLOUD=aws
   export TF_VAR_dev_email="dev-account@example.com"
   ```

2. **AWS credentials** for the root account with Organizations permissions

3. **Terraform ≥ 1.5, Terragrunt ≥ 0.52**

## Deployment Order

### 1. Create Dev Account in AWS Organizations

```bash
cd environments/aws/root/organizations
terragrunt plan
terragrunt apply
```

This creates the `Development` account under the `Workloads` OU. Note the account ID from outputs.

### 2. Deploy Shared VPC and ALB

```bash
cd ../dev/vpc
terragrunt plan
terragrunt apply
```

**Outputs:**
- `vpc_id`: VPC identifier
- `alb_dns_name`: ALB DNS name (e.g., dev-shared-alb-1234567890.us-east-1.elb.amazonaws.com)
- `target_group_arns`: Map with "mgmt" and "apps" ARNs

**Resources created:**
- VPC (10.0.0.0/16)
- 2 public subnets (for ALB)
- 2 private subnets (for Fargate pods)
- Internet Gateway
- NAT Gateway with Elastic IP
- ALB with HTTP listener
- 2 target groups with listener rules
- Security groups

### 3. Deploy Management Cluster (ArgoCD)

```bash
cd ../eks-mgmt
terragrunt plan
terragrunt apply
```

**Duration:** ~15 minutes

**Outputs:**
- `cluster_endpoint`: API endpoint
- `oidc_provider_arn`: For IRSA
- `aws_load_balancer_controller_role_arn`: IAM role for ALB controller

**Resources created:**
- EKS cluster (1.31)
- OIDC provider for IRSA
- Fargate profiles (kube-system, default, argocd)
- IAM roles and policies
- Security groups

### 4. Deploy Application Cluster

```bash
cd ../eks-apps
terragrunt plan
terragrunt apply
```

**Duration:** ~15 minutes

**Outputs:**
- `cluster_endpoint`: API endpoint
- `oidc_provider_arn`: For IRSA
- `aws_load_balancer_controller_role_arn`: IAM role for ALB controller

**Resources created:**
- EKS cluster (1.31)
- OIDC provider for IRSA
- Fargate profiles (kube-system, default, production, staging)
- IAM roles and policies
- Security groups

## Post-Deployment Setup

### Configure kubectl

**Management cluster:**
```bash
aws eks update-kubeconfig --name dev-mgmt-cluster --region us-east-1
kubectl get nodes
```

**Application cluster:**
```bash
aws eks update-kubeconfig --name dev-apps-cluster --region us-east-1 --alias apps
kubectl get nodes --context apps
```

### Install AWS Load Balancer Controller

Choose **one cluster** to install the controller (it can manage targets across both):

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get the IAM role ARN from Terraform outputs
ROLE_ARN=$(cd environments/aws/dev/eks-mgmt && terragrunt output -raw aws_load_balancer_controller_role_arn)

# Install on management cluster
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-mgmt-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ROLE_ARN
```

Verify:
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for pods:
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

Get initial password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Configure ALB Ingress for ArgoCD

The ALB is pre-configured to route `argocd.dev.example.com` to the management cluster's target group. You need to:

1. **Register Fargate pod IPs with target group** (manual until ALB controller is configured):
   ```bash
   # Get ArgoCD server pod IPs
   kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o wide

   # Get target group ARN
   TG_ARN=$(cd environments/aws/dev/vpc && terragrunt output -json target_group_arns | jq -r '.mgmt')

   # Register targets (example - replace with actual IPs)
   aws elbv2 register-targets \
     --target-group-arn $TG_ARN \
     --targets Id=10.0.101.5,Port=8080 Id=10.0.102.6,Port=8080
   ```

2. **Or create Ingress resource** for ALB controller to manage:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: argocd-ingress
     namespace: argocd
     annotations:
       alb.ingress.kubernetes.io/scheme: internet-facing
       alb.ingress.kubernetes.io/target-group-arn: <mgmt-target-group-arn>
   spec:
     ingressClassName: alb
     rules:
     - host: argocd.dev.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: argocd-server
               port:
                 number: 80
   ```

3. **Update DNS:** Point `argocd.dev.example.com` to the ALB DNS name

## Cost Optimization Notes

- **Free tier:** 400 vCPU-hours/month Fargate (~2 small pods 24/7)
- **NAT Gateway:** $32/month unavoidable for internet access
- **ALB:** $16/month shared across both clusters
- **EKS:** $73/month per cluster (no free tier)
- **Data transfer:** Minimal for dev (<$5/month)

**Estimated total: $194/month**

To reduce costs further:
- Delete apps cluster when not needed: saves $73/month
- Use VPC endpoints to avoid NAT Gateway: saves $32/month (but adds ~$7/month per endpoint)
- Disable cluster logging (already default)

## Troubleshooting

**Fargate pods not starting:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check if namespace has Fargate profile
```

**ALB health checks failing:**
- Verify target group health check path matches service
- Check security groups allow ALB → pods traffic
- Verify Fargate pods are in private subnets

**IRSA not working:**
```bash
# Verify OIDC provider
aws iam list-open-id-connect-providers

# Check service account annotation
kubectl get sa <service-account> -n <namespace> -o yaml
```

## Cleanup

**Reverse order to avoid dependencies:**
```bash
cd environments/aws/dev/eks-apps && terragrunt destroy
cd ../eks-mgmt && terragrunt destroy
cd ../vpc && terragrunt destroy
# Organizations account deletion requires AWS support ticket
```

## Next Steps

1. **Multi-account setup:** Deploy to staging/production accounts
2. **ArgoCD apps:** Point to Git repos for application deployment
3. **Observability:** Add Prometheus/Grafana for monitoring
4. **Secrets management:** External Secrets Operator with AWS Secrets Manager
5. **Network policies:** Implement pod-to-pod security
6. **Backup:** Velero for cluster backups
