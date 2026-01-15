#!/bin/bash

# Configuration
PROFILE="cloudmancer"
REGION="us-east-1"
CLUSTER_NAME="task-tracker-cluster"
SERVICE_NAME="task-tracker-service"

echo "========================================="
echo "Task Tracker Deployment Status"
echo "========================================="
echo ""

# Check if service exists
echo "Checking service status..."
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "services[0].status" \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" = "NOT_FOUND" ]; then
  echo "❌ Service not found. Have you run the deployment script?"
  exit 1
fi

echo "Service Status: $SERVICE_STATUS"
echo ""

# Get service details
echo "Service Details:"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "services[0].{
    Status: status,
    DesiredCount: desiredCount,
    RunningCount: runningCount,
    PendingCount: pendingCount,
    LaunchType: launchType
  }" \
  --output table

echo ""

# Get recent events
echo "Recent Events:"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "services[0].events[0:5].{Time: createdAt, Message: message}" \
  --output table

echo ""

# Get load balancer info
echo "Load Balancer:"
LB_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "services[0].loadBalancers[0].targetGroupArn" \
  --output text 2>/dev/null || echo "")

if [ -n "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
  # Get ALB ARN from target group
  ALB_ARN=$(aws elbv2 describe-target-groups \
    --target-group-arns $LB_ARN \
    --profile $PROFILE \
    --region $REGION \
    --query "TargetGroups[0].LoadBalancerArns[0]" \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers \
      --load-balancer-arns $ALB_ARN \
      --profile $PROFILE \
      --region $REGION \
      --query "LoadBalancers[0].DNSName" \
      --output text 2>/dev/null || echo "")
    
    if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
      echo "Application URL: http://$ALB_DNS"
    else
      echo "Load balancer DNS not yet available"
    fi
  else
    echo "Load balancer not yet configured"
  fi
else
  echo "No load balancer attached"
fi

echo ""

# Get task information
echo "Running Tasks:"
TASK_ARNS=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --profile $PROFILE \
  --region $REGION \
  --query "taskArns[]" \
  --output text 2>/dev/null || echo "")

if [ -n "$TASK_ARNS" ]; then
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARNS \
    --profile $PROFILE \
    --region $REGION \
    --query "tasks[].{
      TaskId: taskArn,
      Status: lastStatus,
      Health: healthStatus,
      Started: startedAt
    }" \
    --output table
else
  echo "No tasks currently running"
fi

echo ""
echo "========================================="
