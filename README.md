# ECS Fargate Deployment with Terraform and GitHub Actions

Complete infrastructure as code for deploying a containerized application on AWS ECS Fargate with automated CI/CD using GitHub Actions.

## 📁 Project Structure

```
ecs-infra-wema/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD pipeline
├── .idea/                      # IDE configuration
├── main.tf                     # Main Terraform infrastructure
├── variables.tf                # Variable definitions
├── terraform.tfvars           # Variable values (create from example)
├── Dockerfile                  # Container definition
├── .dockerignore              # Docker ignore rules
├── app.py                     # Python Flask application
├── requirements.txt           # Python dependencies
└── README.md                  # This file
```

## 🏗️ Infrastructure Components

- **VPC**: Multi-AZ with public and private subnets
- **ECS Fargate**: Serverless container orchestration
- **ECR**: Private container registry
- **Application Load Balancer**: HTTP/HTTPS traffic distribution
- **Auto Scaling**: CPU and memory-based scaling
- **CloudWatch Logs**: Centralized logging
- **IAM Roles**: Least privilege security

## 🚀 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured
3. **Terraform** >= 1.0 installed
4. **GitHub Repository** with secrets configured
5. **S3 Bucket** for Terraform state
6. **DynamoDB Table** for state locking

## 📋 Setup Instructions

### 1. Create S3 Bucket for Terraform State

```bash
# Create bucket
aws s3api create-bucket \
  --bucket my-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket my-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Update Terraform Backend Configuration

Edit `main.tf` and update the backend configuration:

```hcl
backend "s3" {
  bucket         = "YOUR-TERRAFORM-STATE-BUCKET"
  key            = "ecs-fargate/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### 4. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region   = "us-east-1"
environment  = "dev"
project_name = "my-app"

vpc_cidr = "10.0.0.0/16"
az_count = 2

app_port          = 8000
health_check_path = "/health"

task_cpu    = "256"
task_memory = "512"

desired_count = 2
min_capacity  = 1
max_capacity  = 4

log_retention_days = 7
```

### 5. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### 6. Update GitHub Actions Workflow

Edit `.github/workflows/deploy.yml` and update these values:

```yaml
env:
  AWS_REGION: us-east-1              # Your AWS region
  ECR_REPOSITORY: my-app-app         # Format: {project_name}-app
  ECS_CLUSTER: my-app-cluster        # Format: {project_name}-cluster
  ECS_SERVICE: my-app-service        # Format: {project_name}-service
  ECS_TASK_DEFINITION: my-app-task   # Format: {project_name}-task
  CONTAINER_NAME: my-app-container   # Format: {project_name}-container
```

## 🎯 Deployment

### Initial Infrastructure Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply
```

### Automated Deployment via GitHub Actions

The pipeline automatically triggers on:
- **Push to `main`**: Deploys to production
- **Push to `develop`**: Deploys to development
- **Pull Request to `main`**: Runs plan only

#### Pipeline Steps:

1. **Terraform**: Plan and apply infrastructure changes
2. **Build**: Create Docker image from Dockerfile
3. **Push**: Upload image to ECR
4. **Deploy**: Update ECS service with new image
5. **Verify**: Wait for service stability

### Manual Deployment

```bash
# Build Docker image
docker build -t my-app .

# Tag image
docker tag my-app:latest {ECR_URL}:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin {ECR_URL}
docker push {ECR_URL}:latest

# Update ECS service
aws ecs update-service \
  --cluster my-app-cluster \
  --service my-app-service \
  --force-new-deployment
```

## 🔍 Monitoring and Debugging

### View Logs

```bash
# ECS Service logs
aws logs tail /ecs/my-app --follow

# Get service status
aws ecs describe-services \
  --cluster my-app-cluster \
  --services my-app-service
```

### Access Application

After deployment, get the ALB URL:

```bash
terraform output alb_dns_name
```

Or via AWS CLI:

```bash
aws elbv2 describe-load-balancers \
  --names my-app-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

Test endpoints:
- `http://{ALB_URL}/` - Main endpoint
- `http://{ALB_URL}/health` - Health check

## 🔐 Security Best Practices

✅ Non-root user in Docker container  
✅ Private subnets for ECS tasks  
✅ Security groups with minimal permissions  
✅ Encrypted Terraform state  
✅ IAM roles with least privilege  
✅ Container image scanning enabled  
✅ CloudWatch logging enabled

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all infrastructure including:
- ECS Cluster and Services
- Load Balancer
- VPC and networking
- ECR Repository (and all images)
- CloudWatch Log Groups

## 📊 Cost Optimization

- Use **FARGATE_SPOT** for non-production environments
- Adjust `desired_count`, `min_capacity`, and `max_capacity`
- Set appropriate `log_retention_days`
- Enable ECR lifecycle policies (already configured)
- Use smaller task sizes for development

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request to `develop`
4. After review, merge to `main` for production

## 📝 Notes

- The sample application is a simple Python HTTP server
- Replace `app.py` with your actual application
- For production, consider using **Gunicorn** or **uWSGI** as WSGI server
- Update `Dockerfile` to use Flask/FastAPI if needed
- Modify health check endpoint if different from `/health`
- Add HTTPS listener and SSL certificate for production

## 🆘 Troubleshooting

### ECS Tasks Not Starting

```bash
# Check task definition
aws ecs describe-task-definition --task-definition my-app-task

# Check service events
aws ecs describe-services \
  --cluster my-app-cluster \
  --services my-app-service \
  --query 'services[0].events[0:5]'
```

### Can't Pull ECR Image

```bash
# Verify ECR authentication
aws ecr get-login-password --region us-east-1

# Check ECR repository
aws ecr describe-repositories --repository-names my-app-app
```

### GitHub Actions Failing

- Verify AWS credentials in GitHub Secrets
- Check IAM permissions match the policy document
- Review workflow logs in Actions tab
- Ensure backend S3 bucket and DynamoDB table exist

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---
