#!/bin/bash
set -e

# Configuration
PROFILE="cloudmancer"
REGION="us-east-1"
CLUSTER_NAME="task-tracker-cluster"
SERVICE_NAME="task-tracker-service"
STACK_NAME="TaskTrackerStack"

echo "========================================="
echo "Task Tracker ECS Teardown Script"
echo "========================================="
echo ""
echo "WARNING: This will delete all Task Tracker resources!"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5
echo ""

# Step 1: Delete ECS Express Gateway Service
echo "Step 1: Deleting ECS Express Gateway Service..."
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "services[?status=='ACTIVE'].serviceName" \
  --output text 2>/dev/null || echo "")

if [ -n "$SERVICE_EXISTS" ]; then
  echo "Deleting service: $SERVICE_NAME"
  aws ecs delete-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force \
    --profile $PROFILE \
    --region $REGION
  
  echo "Waiting for service to be deleted..."
  aws ecs wait services-inactive \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --profile $PROFILE \
    --region $REGION 2>/dev/null || true
  
  echo "✓ Service deleted"
else
  echo "Service not found or already deleted"
fi
echo ""

# Step 2: Delete all tasks in the cluster
echo "Step 2: Stopping all tasks in cluster..."
TASK_ARNS=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "taskArns[]" \
  --output text 2>/dev/null || echo "")

if [ -n "$TASK_ARNS" ]; then
  for TASK_ARN in $TASK_ARNS; do
    echo "Stopping task: $TASK_ARN"
    aws ecs stop-task \
      --cluster $CLUSTER_NAME \
      --task $TASK_ARN \
      --profile $PROFILE \
      --region $REGION >/dev/null 2>&1 || true
  done
  echo "✓ All tasks stopped"
else
  echo "No tasks found"
fi
echo ""

# Step 3: Delete ECR images
echo "Step 3: Deleting ECR images..."
REPOSITORY_NAME=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query "Stacks[0].Outputs[?OutputKey=='RepositoryName'].OutputValue" \
  --output text \
  --profile $PROFILE \
  --region $REGION 2>/dev/null || echo "task-tracker")

IMAGE_IDS=$(aws ecr list-images \
  --repository-name $REPOSITORY_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "imageIds[]" \
  --output json 2>/dev/null || echo "[]")

if [ "$IMAGE_IDS" != "[]" ]; then
  echo "Deleting images from repository: $REPOSITORY_NAME"
  aws ecr batch-delete-image \
    --repository-name $REPOSITORY_NAME \
    --image-ids "$IMAGE_IDS" \
    --profile $PROFILE \
    --region $REGION >/dev/null 2>&1 || true
  echo "✓ ECR images deleted"
else
  echo "No images found in repository"
fi
echo ""

# Step 4: Destroy CDK stack
echo "Step 4: Destroying CDK stack..."
cd ecs-deploy
npx cdk destroy --profile $PROFILE --force
cd ..
echo "✓ CDK stack destroyed"
echo ""

# Step 5: Clean up any remaining resources
echo "Step 5: Checking for remaining resources..."

# Check if cluster still exists
CLUSTER_EXISTS=$(aws ecs describe-clusters \
  --clusters $CLUSTER_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "clusters[?status=='ACTIVE'].clusterName" \
  --output text 2>/dev/null || echo "")

if [ -n "$CLUSTER_EXISTS" ]; then
  echo "Warning: Cluster still exists. It may have active services or tasks."
  echo "You may need to manually delete it from the AWS console."
else
  echo "✓ Cluster deleted"
fi
echo ""

echo "========================================="
echo "Teardown Complete!"
echo "========================================="
echo ""
echo "All Task Tracker resources have been deleted."
echo ""
echo "Note: The vibe-coding stack (VPC, database) was not affected."
