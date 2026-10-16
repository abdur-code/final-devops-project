# Infrastructure (Terraform on AWS)

The configuration creates, in order:

1. A VPC with 2 public and 2 private subnets across 2 AZs and a NAT gateway.
2. An EKS cluster with a managed node group (AL2023, t3.medium × 2).
3. The cluster add-ons: VPC CNI with NetworkPolicy, CoreDNS, kube-proxy, the Pod Identity agent, and the EBS CSI
   driver for persistent volumes.
4. An IAM role that GitHub Actions can assume via OIDC.

```bash
aws configure                       # or: export AWS_PROFILE=...
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit (restrict endpoint_public_access_cidrs to your IP)
terraform init
terraform plan -out tfplan
terraform apply tfplan              # ~15-20 min
$(terraform output -raw configure_kubectl)
kubectl get nodes
```

The EKS control plane, the NAT gateway and 2 nodes cost about US$5-7 per day while running.

## Teardown order
Resources that Kubernetes creates, such as the ingress load balancer and the EBS volumes behind PVCs, are not in
Terraform state. Remove them first, otherwise they block VPC deletion and keep billing:

```bash
kubectl delete -f gitops/argocd/root-app.yaml        # cascades: Argo CD deletes every app it manages
kubectl delete ns stockpilot stockpilot-raw stockpilot-helm monitoring --ignore-not-found   # removes PVCs (StatefulSet PVCs outlive their StatefulSet)
helm uninstall ingress-nginx -n ingress-nginx        # removes the AWS load balancer
kubectl get pvc -A                                   # should be empty
terraform destroy
```

The configuration is split into `versions.tf` (pins), `providers.tf`, `variables.tf`, `vpc.tf`, `eks.tf`,
`github-oidc.tf`, `outputs.tf` and `backend.tf.example` (S3 remote state with native locking). CI runs `fmt`,
`validate` and a Trivy scan on every change.
