# Quick Start Guide

## Deploy Task Tracker to ECS

**Option 1: Bash script**
```bash
./ecs-deploy/deploy.sh
```

**Option 2: Python with ECS MCP Server**
```bash
cd ecs-deploy && python3 deploy-with-mcp.py
```

## Teardown

Run from project root:

```bash
./ecs-deploy/teardown.sh
```

## What Gets Created

1. **ECS Cluster**: task-tracker-cluster
2. **ECR Repository**: task-tracker
3. **IAM Roles**:
   - ecsTaskTrackerExecutionRole (for ECS agent)
   - ecsTaskTrackerInfrastructureRole (for AWS resource management)
   - ecsTaskTrackerTaskRole (for application)
4. **ECS Express Gateway Service**:
   - Application Load Balancer
   - Auto Scaling
   - Security Groups
   - Target Groups

## Check Status

```bash
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1
```

## Important Notes

- Uses existing `vibe-coding` VPC and database
- Database credentials from Secrets Manager (no plain text)
- Runs on private subnets
- Container runs as non-root user
- Built for linux/amd64 platform
- Exposes port 8080
- Health check at `/health`
