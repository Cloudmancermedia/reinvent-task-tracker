# Task Tracker Deployment Checklist

Use this checklist to ensure a smooth deployment.

## Pre-Deployment Checklist

### Environment Setup
- [ ] AWS CLI installed and configured
- [ ] AWS profile `cloudmancer` is configured and working
- [ ] Docker is installed and running
- [ ] Node.js and npm are installed
- [ ] Python 3 is installed (for alternative deployment)

### Verify Prerequisites
```bash
# Check AWS credentials
aws sts get-caller-identity --profile cloudmancer

# Check Docker
docker --version
docker ps

# Check Node.js
node --version
npm --version

# Check Python
python3 --version
```

### Verify Existing Infrastructure
- [ ] `vibe-coding` CloudFormation stack exists
- [ ] VPC and subnets are available
- [ ] Aurora PostgreSQL database is running
- [ ] Database credentials are in Secrets Manager

```bash
# Verify CloudFormation exports
aws cloudformation list-exports \
  --profile cloudmancer \
  --region us-east-1 \
  --query "Exports[?starts_with(Name, 'vibe-coding')].{Name:Name,Value:Value}" \
  --output table
```

Expected exports:
- [ ] `vibe-coding-VPC-ID`
- [ ] `vibe-coding-Pvt-Subnet-1`
- [ ] `vibe-coding-Pvt-Subnet-2`
- [ ] `vibe-coding-Pvt-Subnet-3`
- [ ] `vibe-coding-Pub-Subnet1`
- [ ] `vibe-coding-Pub-Subnet2`
- [ ] `vibe-coding-Pub-Subnet3`
- [ ] `vibe-coding-DB-Cluster-Endpoint`
- [ ] `vibe-coding-DB-Name`
- [ ] `vibe-coding-DB-Secret-ARN`

## Deployment Checklist

### Step 1: Review Configuration
- [ ] Review `ecs-deploy/lib/task-tracker-stack.ts` for IAM roles
- [ ] Review `ecs-deploy/deploy.sh` for deployment settings
- [ ] Confirm desired count is set to 3 replicas
- [ ] Confirm CPU (512) and memory (1024) settings

### Step 2: Execute Deployment

Choose one option:

**Option A: Bash Script**
- [ ] Make script executable: `chmod +x ecs-deploy/deploy.sh`
- [ ] Run from project root: `./ecs-deploy/deploy.sh`

**Option B: Python Script**
- [ ] Make script executable: `chmod +x ecs-deploy/deploy-with-mcp.py`
- [ ] Run from project root: `cd ecs-deploy && python3 deploy-with-mcp.py`

### Step 3: Monitor Deployment
- [ ] CDK dependencies installed successfully
- [ ] CDK bootstrap completed (if first time)
- [ ] CDK stack deployed successfully
- [ ] Stack outputs retrieved
- [ ] VPC and database info retrieved
- [ ] ECR login successful
- [ ] Docker image built for linux/amd64
- [ ] Image pushed to ECR
- [ ] ECS Express Gateway Service created
- [ ] Service shows 3 desired tasks

### Step 4: Verify Deployment

```bash
# Check service status
./ecs-deploy/check-status.sh

# Or manually
aws ecs describe-services \
  --cluster task-tracker-cluster \
  --services task-tracker-service \
  --profile cloudmancer \
  --region us-east-1
```

Verify:
- [ ] Service status is `ACTIVE`
- [ ] Desired count is `3`
- [ ] Running count is `3`
- [ ] Pending count is `0`
- [ ] No error events in service events

### Step 5: Test Application

```bash
# Get ALB DNS name from check-status.sh output or AWS Console
# Test health endpoint
curl http://<ALB-DNS-NAME>/health

# Test main application
curl http://<ALB-DNS-NAME>/
```

- [ ] Health check returns `OK`
- [ ] Application loads successfully
- [ ] Can view tasks in the UI
- [ ] Database connection is working

### Step 6: Monitor Logs

```bash
# View logs
aws logs tail /ecs/task-tracker-service --follow \
  --profile cloudmancer \
  --region us-east-1
```

- [ ] No error messages in logs
- [ ] Application started successfully
- [ ] Database connection established

## Post-Deployment Checklist

### Verify Resources Created
- [ ] ECS Cluster: `task-tracker-cluster` exists
- [ ] ECR Repository: `task-tracker` exists with image
- [ ] ECS Service: `task-tracker-service` is running
- [ ] 3 tasks are running and healthy
- [ ] Application Load Balancer is created
- [ ] Target groups are healthy
- [ ] Security groups are configured
- [ ] IAM roles exist:
  - [ ] `ecsTaskTrackerExecutionRole`
  - [ ] `ecsTaskTrackerInfrastructureRole`
  - [ ] `ecsTaskTrackerTaskRole`

### Security Verification
- [ ] Database credentials are NOT in plain text
- [ ] Secrets are injected from Secrets Manager
- [ ] Tasks are running in private subnets
- [ ] Container runs as non-root user
- [ ] Security groups allow only necessary traffic

### Performance Verification
- [ ] All 3 tasks are healthy
- [ ] Load balancer distributes traffic evenly
- [ ] Health checks are passing
- [ ] Auto-scaling is configured (min 3, max 6)

## Troubleshooting Checklist

If deployment fails, check:

### CDK Issues
- [ ] Node.js version is compatible
- [ ] npm install completed without errors
- [ ] AWS credentials have sufficient permissions
- [ ] CDK bootstrap was successful

### Docker Issues
- [ ] Docker daemon is running
- [ ] Sufficient disk space for image build
- [ ] All application files are present
- [ ] Dockerfile syntax is correct

### ECR Issues
- [ ] ECR repository was created
- [ ] ECR login was successful
- [ ] Image push completed
- [ ] Image tag is `latest`

### ECS Issues
- [ ] Cluster was created successfully
- [ ] Service creation command completed
- [ ] Task definition is valid
- [ ] IAM roles have correct permissions
- [ ] Network configuration is correct

### Database Issues
- [ ] Database endpoint is reachable from private subnets
- [ ] Security groups allow traffic from ECS tasks
- [ ] Database credentials in Secrets Manager are correct
- [ ] Database name matches configuration

### Network Issues
- [ ] VPC exists and is active
- [ ] Private subnets exist
- [ ] NAT Gateway is configured (for ECR access)
- [ ] Route tables are correct
- [ ] Security groups allow necessary traffic

## Rollback Checklist

If you need to rollback:

- [ ] Run teardown script: `./ecs-deploy/teardown.sh`
- [ ] Verify service is deleted
- [ ] Verify tasks are stopped
- [ ] Verify ECR images are deleted
- [ ] Verify CDK stack is destroyed
- [ ] Verify IAM roles are deleted
- [ ] Verify cluster is deleted

## Success Criteria

Deployment is successful when:

✅ All 3 tasks are running and healthy  
✅ Application is accessible via ALB URL  
✅ Health check endpoint returns `OK`  
✅ Application can connect to database  
✅ Tasks can read/write data  
✅ No errors in CloudWatch Logs  
✅ Load balancer health checks are passing  
✅ Auto-scaling is configured correctly  

## Next Steps After Successful Deployment

- [ ] Document the ALB URL
- [ ] Set up CloudWatch alarms
- [ ] Configure custom domain (optional)
- [ ] Enable HTTPS with ACM certificate (optional)
- [ ] Set up CI/CD pipeline (optional)
- [ ] Configure backup strategy
- [ ] Document operational procedures
- [ ] Train team on monitoring and troubleshooting

## Notes

- Deployment typically takes 10-15 minutes
- First CDK bootstrap can take additional 5 minutes
- Service stabilization can take 5-10 minutes
- Keep the terminal output for reference
- Save the ALB URL for future access

## Support Resources

- AWS ECS Documentation: https://docs.aws.amazon.com/ecs/
- ECS Express Mode: https://docs.aws.amazon.com/cli/latest/reference/ecs/create-express-gateway-service.html
- AWS CDK Documentation: https://docs.aws.amazon.com/cdk/
- Troubleshooting Guide: See `DEPLOYMENT_GUIDE.md`
