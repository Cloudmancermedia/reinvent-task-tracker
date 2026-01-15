#!/bin/bash
set -e

# Configuration
PROFILE="cloudmancer"
REGION="us-east-1"
CLUSTER_NAME="task-tracker-cluster"
SERVICE_NAME="task-tracker-service"
REPOSITORY_NAME="task-tracker"

echo "========================================="
echo "Task Tracker ECS Deployment Script"
echo "========================================="
echo ""

# Step 1: Install CDK dependencies
echo "Step 1: Installing CDK dependencies..."
cd ecs-deploy
npm install
cd ..
echo "✓ Dependencies installed"
echo ""

# Step 2: Bootstrap CDK (if not already done)
echo "Step 2: Bootstrapping CDK..."
cd ecs-deploy
npx cdk bootstrap --profile $PROFILE
cd ..
echo "✓ CDK bootstrapped"
echo ""

# Step 3: Deploy CDK stack
echo "Step 3: Deploying CDK stack..."
cd ecs-deploy
npx cdk deploy --profile $PROFILE --require-approval never
cd ..
echo "✓ CDK stack deployed"
echo ""

# Step 4: Get stack outputs
echo "Step 4: Retrieving stack outputs..."
REPOSITORY_URI=$(aws cloudformation describe-stacks \
  --stack-name TaskTrackerStack \
  --query "Stacks[0].Outputs[?OutputKey=='RepositoryUri'].OutputValue" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

EXECUTION_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name TaskTrackerStack \
  --query "Stacks[0].Outputs[?OutputKey=='TaskExecutionRoleArn'].OutputValue" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

INFRASTRUCTURE_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name TaskTrackerStack \
  --query "Stacks[0].Outputs[?OutputKey=='InfrastructureRoleArn'].OutputValue" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

TASK_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name TaskTrackerStack \
  --query "Stacks[0].Outputs[?OutputKey=='TaskRoleArn'].OutputValue" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

echo "Repository URI: $REPOSITORY_URI"
echo "Execution Role ARN: $EXECUTION_ROLE_ARN"
echo "Infrastructure Role ARN: $INFRASTRUCTURE_ROLE_ARN"
echo "Task Role ARN: $TASK_ROLE_ARN"
echo ""

# Step 5: Get existing VPC and database information
echo "Step 5: Retrieving existing VPC and database information..."
VPC_ID=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-VPC-ID'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

SUBNET_1=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-Pvt-Subnet-1'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

SUBNET_2=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-Pvt-Subnet-2'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

SUBNET_3=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-Pvt-Subnet-3'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

DB_ENDPOINT=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-DB-Cluster-Endpoint'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

DB_NAME=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-DB-Name'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

DB_SECRET_ARN=$(aws cloudformation list-exports \
  --query "Exports[?Name=='vibe-coding-DB-Secret-ARN'].Value" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

echo "VPC ID: $VPC_ID"
echo "Subnets: $SUBNET_1, $SUBNET_2, $SUBNET_3"
echo "DB Endpoint: $DB_ENDPOINT"
echo "DB Name: $DB_NAME"
echo "DB Secret ARN: $DB_SECRET_ARN"
echo ""

# Step 6: Login to ECR
echo "Step 6: Logging in to ECR..."
aws ecr get-login-password --region $REGION --profile $PROFILE | \
  docker login --username AWS --password-stdin $REPOSITORY_URI
echo "✓ Logged in to ECR"
echo ""

# Step 7: Build Docker image for linux/amd64
echo "Step 7: Building Docker image for linux/amd64..."
docker build --platform linux/amd64 -t $REPOSITORY_NAME:latest -f ecs-deploy/Dockerfile .
echo "✓ Docker image built"
echo ""

# Step 8: Tag and push image to ECR
echo "Step 8: Tagging and pushing image to ECR..."
docker tag $REPOSITORY_NAME:latest $REPOSITORY_URI:latest
docker push $REPOSITORY_URI:latest
echo "✓ Image pushed to ECR"
echo ""

# Step 9: Create ECS Express Gateway Service using ECS MCP Server
echo "Step 9: Creating ECS Express Gateway Service with 3 replicas..."
echo "Note: Using ECS MCP Server to create Express Gateway Service"
echo ""

# Create a JSON file for the primary container configuration
cat > /tmp/primary-container.json <<EOF
{
  "image": "$REPOSITORY_URI:latest",
  "containerPort": 8080,
  "environment": [
    {"name": "DB_HOST", "value": "$DB_ENDPOINT"},
    {"name": "DB_NAME", "value": "$DB_NAME"},
    {"name": "DB_PORT", "value": "5432"}
  ],
  "secrets": [
    {"name": "DB_USERNAME", "valueFrom": "$DB_SECRET_ARN:username::"},
    {"name": "DB_PASSWORD", "valueFrom": "$DB_SECRET_ARN:password::"}
  ]
}
EOF

# Create a JSON file for network configuration
cat > /tmp/network-config.json <<EOF
{
  "awsvpcConfiguration": {
    "subnets": ["$SUBNET_1", "$SUBNET_2", "$SUBNET_3"],
    "assignPublicIp": "DISABLED"
  }
}
EOF

# Create the service using AWS CLI with proper JSON formatting
aws ecs create-express-gateway-service \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --execution-role-arn $EXECUTION_ROLE_ARN \
  --infrastructure-role-arn $INFRASTRUCTURE_ROLE_ARN \
  --task-role-arn $TASK_ROLE_ARN \
  --health-check-path "/health" \
  --primary-container file:///tmp/primary-container.json \
  --network-configuration file:///tmp/network-config.json \
  --cpu 512 \
  --memory 1024 \
  --scaling-target "desiredCount=3,minCapacity=3,maxCapacity=6" \
  --profile $PROFILE \
  --region $REGION

# Clean up temporary files
rm -f /tmp/primary-container.json /tmp/network-config.json

echo "✓ ECS Express Gateway Service created with 3 replicas"
echo ""

# Step 10: Get service URL
echo "Step 10: Retrieving service URL..."
sleep 10
SERVICE_URL=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query "services[0].loadBalancers[0].targetGroupArn" \
  --output text \
  --profile $PROFILE \
  --region $REGION)

echo "Service URL will be available once the service is fully deployed."
echo "Check the ECS console for the service URL."
echo ""

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Repository: $REPOSITORY_URI"
echo ""
echo "To check service status:"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --profile $PROFILE --region $REGION"
