# Task Tracker ECS Deployment

This directory contains the AWS CDK infrastructure and deployment scripts for migrating the Task Tracker application to Amazon ECS using ECS Express Mode.

## Architecture

- **ECS Cluster**: `task-tracker-cluster`
- **ECR Repository**: `task-tracker`
- **Deployment Mode**: ECS Express Gateway Service
- **Compute**: AWS Fargate
- **Database**: Aurora PostgreSQL (from existing `vibe-coding` stack)
- **Networking**: Private subnets with Application Load Balancer

## Prerequisites

1. AWS CLI configured with `cloudmancer` profile
2. Docker installed and running
3. Node.js and npm installed
4. Existing `vibe-coding` CloudFormation stack with:
   - VPC and subnets
   - Aurora PostgreSQL database
   - Database credentials in Secrets Manager

## Infrastructure Components

### IAM Roles

1. **ecsTaskTrackerExecutionRole**: Used by ECS agent to pull images, write logs, and access secrets
   - Managed Policy: `AmazonECSTaskExecutionRolePolicy`
   - Additional permissions for Secrets Manager access

2. **ecsTaskTrackerInfrastructureRole**: Used by ECS to create and manage AWS resources
   - Permissions for ALB, security groups, auto-scaling, CloudWatch

3. **ecsTaskTrackerTaskRole**: Used by application code to access AWS services
   - Permissions for CloudWatch Logs

### Resources Created

- ECS Cluster: `task-tracker-cluster`
- ECR Repository: `task-tracker`
- IAM Roles (3 roles as described above)
- ECS Express Gateway Service (created during deployment)
  - Application Load Balancer
  - Target Groups
  - Security Groups
  - Auto Scaling Policies

## Deployment

### Step 1: Deploy Infrastructure

From the project root, run:

```bash
chmod +x ecs-deploy/deploy.sh
./ecs-deploy/deploy.sh
```

**Alternative: Python deployment script with ECS MCP Server**
```bash
chmod +x ecs-deploy/deploy-with-mcp.py
cd ecs-deploy && python3 deploy-with-mcp.py
```

This script will:
1. Install CDK dependencies
2. Bootstrap CDK (if needed)
3. Deploy the CDK stack (cluster, ECR, IAM roles)
4. Retrieve existing VPC and database information from `vibe-coding` stack
5. Build Docker image for linux/amd64
6. Push image to ECR
7. Create ECS Express Gateway Service with:
   - **Desired count: 3 replicas**
   - Container port: 8080
   - Health check: `/health`
   - Database credentials from Secrets Manager (secure injection)
   - Private subnet deployment
   - Auto-scaling: min 3, max 6 tasks

### Step 2: Verify Deployment

Check the service status:

```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1
```

Get the Application Load Balancer URL from the ECS console or service description.

## Teardown

To delete all resources:

```bash
chmod +x ecs-deploy/teardown.sh
./ecs-deploy/teardown.sh
```

This will:
1. Delete the ECS Express Gateway Service
2. Stop all running tasks
3. Delete ECR images
4. Destroy the CDK stack
5. Clean up remaining resources

**Note**: The `vibe-coding` stack (VPC, database) will not be affected.

## Configuration

### Environment Variables

The application receives these environment variables:
- `DB_HOST`: Database endpoint (from CloudFormation export)
- `DB_NAME`: Database name (from CloudFormation export)
- `DB_PORT`: Database port (5432)

### Secrets

Database credentials are injected as secrets from AWS Secrets Manager:
- `DB_USERNAME`: From `vibe-coding-DB-Secret-ARN`
- `DB_PASSWORD`: From `vibe-coding-DB-Secret-ARN`

### Networking

- **Subnets**: Private subnets from `vibe-coding` stack
- **Public IP**: Disabled (private deployment)
- **Load Balancer**: Automatically created by ECS Express Mode

## Customization

To modify the deployment:

1. **Change CPU/Memory**: Edit `deploy.sh` and update `--cpu` and `--memory` values
2. **Add Environment Variables**: Edit the `--primary-container` section in `deploy.sh`
3. **Modify IAM Permissions**: Edit `lib/task-tracker-stack.ts`
4. **Change Health Check**: Update `--health-check-path` in `deploy.sh`

## Troubleshooting

### Check Service Events

```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1 \
  --query "services[0].events[0:5]"
```

### Check Task Logs

```bash
aws logs tail /ecs/task-tracker-service --follow \
  --profile cloudmancer \
  --region us-east-1
```

### Verify Database Connectivity

Ensure the ECS tasks have network access to the Aurora database in the private subnets.

## Notes

- All Docker images are built for `linux/amd64` platform
- Application runs as non-root user (appuser, UID 1000)
- Container exposes port 8080
- Health check endpoint: `/health`
- IAM role names begin with `ecsTaskTracker` as per best practices
