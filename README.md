# terraform-express-pipeline
terraform-express-pipeline on AWS using ArgoCD

## Project Structure
├── infra                # Root Terraform configurations
├── modules              # Reusable Terraform modules
├── env                  # Environment-specific variable files 
│   └── dev
│       └── us-east-1
│           └── terraform.auto.tfvars
├── app                  # Express.js application and Jest tests
├── deploy               # Deployment manifests (e.g., ArgoCD configurations)
└── test
    ├── kuttl          # KUTTL integration tests
    └── k6             # k6 performance tests
