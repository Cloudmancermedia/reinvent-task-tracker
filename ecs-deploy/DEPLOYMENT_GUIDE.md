# Task Tracker ECS Deployment Guide

## Overview

This guide walks you through deploying the Task Tracker application to Amazon ECS using **ECS Express Mode** with **AWS CDK** (instead of CloudFormation templates).

## Key Features

✅ **CDK Infrastructure** - Modern infrastructure as code with TypeScript  
✅ **ECS Express Mode** - Simplified deployment with automatic ALB, security groups, and auto-scaling  
✅ **3 Replicas** - High availability with 3 task instances  
✅ **Auto-scaling** - Scales between 3-6 tasks based on demand  
✅ **Secure Secrets** - Database credentials injected from Secrets Manager  
✅ **Private Deployment** - Tasks run in private subnets  
✅ **ECS MCP Server** - Uses ECS MCP Server for service creation  

## Prerequisites

Before you begin, ensure you have:

1. ✅ AWS CLI configured with `cloudmancer` profile
2. ✅ Docker installed and running
3. ✅ Node.js and npm installed (for CDK)
4. ✅ Python 3 installed (for alternative deployment script)
5. ✅ Existing `vibe-coding` CloudFormation stack with:
   - VPC and subnets (public and private)
   - Aurora PostgreSQL database
   - Database credentials in Secrets Manager

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Gateway                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (Public)              │
│                    (Created by Express Mode)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌────────┐      ┌────────┐      ┌────────┐
    │ Task 1 │      │ Task 2 │      │ Task 3 │
    │ (8080) │      │ (8080) │      │ (8080) │
    └────┬───┘      └────┬───┘      └────┬───┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
              ┌──────────────────────┐
              │  Aurora PostgreSQL   │
              │  (vibe-coding stack) │
              └──────────────────────┘
```

## Deployment Steps

### Option 1: Bash Script (Recommended)

From the **project root**, run:

```bash
./ecs-deploy/deploy.sh
```

### Option 2: Python Script with ECS MCP Server

From the **project root**, run:

```bash
cd ecs-deploy && python3 deploy-with-mcp.py
```

## What Happens During Deployment

### Phase 1: CDK Infrastructure (Steps 1-3)
1. **Install Dependencies** - npm packages for CDK
2. **Bootstrap CDK** - Prepare AWS account for CDK (one-time)
3. **Deploy Stack** - Creates:
   - ECS Cluster: `task-tracker-cluster`
   - ECR Repository: `task-tracker`
   - IAM Roles:
     - `ecsTaskTrackerExecutionRole` (for ECS agent)
     - `ecsTaskTrackerInfrastructureRole` (for AWS resources)
     - `ecsTaskTrackerTaskRole` (for application)

### Phase 2: Container Build & Push (Steps 4-8)
4. **Retrieve Outputs** - Get ARNs and URIs from CDK stack
5. **Get VPC Info** - Import from `vibe-coding` CloudFormation exports:
   - VPC ID
   - Private subnets (3)
   - Database endpoint
   - Database name
   - Secrets Manager ARN
6. **ECR Login** - Authenticate Docker with ECR
7. **Build Image** - Build for `linux/amd64` platform
8. **Push Image** - Upload to ECR repository

### Phase 3: ECS Service Creation (Steps 9-10)
9. **Create Express Service** - Using ECS MCP Server:
   - Service name: `task-tracker-service`
   - Desired count: **3 replicas**
   - Auto-scaling: min 3, max 6
   - Container port: 8080
   - Health check: `/health`
   - Environment variables: DB_HOST, DB_NAME, DB_PORT
   - Secrets: DB_USERNAME, DB_PASSWORD (from Secrets Manager)
   - Network: Private subnets, no public IP
   - Resources: 512 CPU, 1024 MB memory per task
10. **Verify Deployment** - Check service status

## Configuration Details

### Container Configuration
```json
{
  "image": "<account>.dkr.ecr.us-east-1.amazonaws.com/task-tracker:latest",
  "containerPort": 8080,
  "environment": [
    {"name": "DB_HOST", "value": "<from vibe-coding export>"},
    {"name": "DB_NAME", "value": "<from vibe-coding export>"},
    {"name": "DB_PORT", "value": "5432"}
  ],
  "secrets": [
    {"name": "DB_USERNAME", "valueFrom": "<secret-arn>:username::"},
    {"name": "DB_PASSWORD", "valueFrom": "<secret-arn>:password::"}
  ]
}
```

### Network Configuration
```json
{
  "awsvpcConfiguration": {
    "subnets": [
      "<vibe-coding-Pvt-Subnet-1>",
      "<vibe-coding-Pvt-Subnet-2>",
      "<vibe-coding-Pvt-Subnet-3>"
    ],
    "assignPublicIp": "DISABLED"
  }
}
```

### Scaling Configuration
- **Desired Count**: 3 tasks
- **Minimum Capacity**: 3 tasks
- **Maximum Capacity**: 6 tasks
- **Auto-scaling**: Managed by ECS Express Mode

## Post-Deployment

### Check Service Status

```bash
./ecs-deploy/check-status.sh
```

Or manually:

```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1
```

### Get Application URL

The Application Load Balancer URL will be displayed in the service details. Access it via:

```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1 \
  --query "services[0].loadBalancers"
```

Then get the ALB DNS name from the AWS Console or CLI.

### View Logs

```bash
aws logs tail /ecs/task-tracker-service --follow \
  --profile cloudmancer \
  --region us-east-1
```

## Teardown

To remove all resources:

```bash
./ecs-deploy/teardown.sh
```

This will:
1. Delete the ECS Express Gateway Service
2. Stop all running tasks (all 3 replicas)
3. Delete ECR images
4. Destroy the CDK stack
5. Clean up remaining resources

**Note**: The `vibe-coding` stack is NOT affected.

## Troubleshooting

### Service Won't Start

Check service events:
```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1 \
  --query "services[0].events[0:10]"
```

### Database Connection Issues

Verify:
1. Security groups allow traffic from ECS tasks to Aurora
2. Database is in the same VPC
3. Secrets Manager ARN is correct
4. Database endpoint is accessible from private subnets

### Tasks Keep Restarting

Check:
1. Health check endpoint `/health` is responding
2. Application logs for errors
3. Database credentials are correct
4. Container has network access to database

### Image Build Fails

Ensure:
1. Docker is running
2. Building for `linux/amd64` platform
3. All application files are present
4. Dockerfile is in `ecs-deploy/` directory

## Customization

### Change Number of Replicas

Edit `deploy.sh` or `deploy-with-mcp.py`:

```bash
# In deploy.sh
--scaling-target "desiredCount=5,minCapacity=5,maxCapacity=10"

# In deploy-with-mcp.py
scalingTarget={
    "desiredCount": 5,
    "minCapacity": 5,
    "maxCapacity": 10
}
```

### Change CPU/Memory

Edit the deployment script:

```bash
--cpu 1024 \
--memory 2048
```

### Add Environment Variables

Edit the `primaryContainer` configuration in the deployment script:

```json
"environment": [
  {"name": "DB_HOST", "value": "..."},
  {"name": "NEW_VAR", "value": "new_value"}
]
```

### Modify IAM Permissions

Edit `ecs-deploy/lib/task-tracker-stack.ts` and add policies to the appropriate role.

## Security Best Practices

✅ **No Plain Text Secrets** - All credentials from Secrets Manager  
✅ **Non-Root User** - Container runs as `appuser` (UID 1000)  
✅ **Private Deployment** - Tasks in private subnets  
✅ **Least Privilege IAM** - Minimal permissions for each role  
✅ **Image Scanning** - ECR scans images for vulnerabilities  
✅ **Role Naming** - All roles prefixed with `ecsTaskTracker`  

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| ECS Cluster | task-tracker-cluster | Hosts the service |
| ECR Repository | task-tracker | Stores container images |
| ECS Service | task-tracker-service | Runs 3 task replicas |
| IAM Role | ecsTaskTrackerExecutionRole | ECS agent permissions |
| IAM Role | ecsTaskTrackerInfrastructureRole | AWS resource management |
| IAM Role | ecsTaskTrackerTaskRole | Application permissions |
| ALB | (auto-generated) | Load balancer (Express Mode) |
| Target Groups | (auto-generated) | Traffic routing (Express Mode) |
| Security Groups | (auto-generated) | Network access (Express Mode) |
| Auto Scaling | (auto-generated) | Scale 3-6 tasks (Express Mode) |

## Cost Estimate

Approximate monthly costs (us-east-1):

- **Fargate Tasks** (3 × 0.5 vCPU, 1 GB): ~$30-40/month
- **Application Load Balancer**: ~$16-20/month
- **Data Transfer**: Variable
- **ECR Storage**: ~$1/month (minimal)
- **CloudWatch Logs**: ~$5/month

**Total**: ~$52-66/month (excluding data transfer)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS ECS Express Mode documentation
3. Check CloudWatch Logs for application errors
4. Verify `vibe-coding` stack exports are available

## Next Steps

After successful deployment:

1. ✅ Access the application via ALB URL
2. ✅ Monitor CloudWatch metrics
3. ✅ Set up CloudWatch alarms for failures
4. ✅ Configure custom domain (optional)
5. ✅ Enable HTTPS with ACM certificate (optional)
6. ✅ Set up CI/CD pipeline (optional)
