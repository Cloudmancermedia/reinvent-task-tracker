#!/usr/bin/env python3
"""
Deployment script using ECS MCP Server to create Express Gateway Service
"""

import boto3
import json
import subprocess
import sys
import time

# Configuration
PROFILE = "cloudmancer"
REGION = "us-east-1"
CLUSTER_NAME = "task-tracker-cluster"
SERVICE_NAME = "task-tracker-service"
REPOSITORY_NAME = "task-tracker"
STACK_NAME = "TaskTrackerStack"

def run_command(cmd, shell=False):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd if shell else cmd.split(),
            capture_output=True,
            text=True,
            check=True,
            shell=shell
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {e}")
        print(f"Output: {e.stdout}")
        print(f"Error: {e.stderr}")
        sys.exit(1)

def get_boto3_session():
    """Create boto3 session with profile"""
    return boto3.Session(profile_name=PROFILE, region_name=REGION)

def main():
    print("=" * 50)
    print("Task Tracker ECS Deployment with MCP Server")
    print("=" * 50)
    print()

    session = get_boto3_session()
    cfn_client = session.client('cloudformation')
    ecs_client = session.client('ecs')
    ecr_client = session.client('ecr')

    # Step 1: Install CDK dependencies
    print("Step 1: Installing CDK dependencies...")
    run_command("npm install", shell=True)
    print("✓ Dependencies installed\n")

    # Step 2: Bootstrap CDK
    print("Step 2: Bootstrapping CDK...")
    run_command(f"npx cdk bootstrap --profile {PROFILE}", shell=True)
    print("✓ CDK bootstrapped\n")

    # Step 3: Deploy CDK stack
    print("Step 3: Deploying CDK stack...")
    run_command(f"npx cdk deploy --profile {PROFILE} --require-approval never", shell=True)
    print("✓ CDK stack deployed\n")

    # Step 4: Get stack outputs
    print("Step 4: Retrieving stack outputs...")
    stack = cfn_client.describe_stacks(StackName=STACK_NAME)['Stacks'][0]
    outputs = {o['OutputKey']: o['OutputValue'] for o in stack['Outputs']}
    
    repository_uri = outputs['RepositoryUri']
    execution_role_arn = outputs['TaskExecutionRoleArn']
    infrastructure_role_arn = outputs['InfrastructureRoleArn']
    task_role_arn = outputs['TaskRoleArn']
    
    print(f"Repository URI: {repository_uri}")
    print(f"Execution Role ARN: {execution_role_arn}")
    print(f"Infrastructure Role ARN: {infrastructure_role_arn}")
    print(f"Task Role ARN: {task_role_arn}\n")

    # Step 5: Get VPC and database information
    print("Step 5: Retrieving VPC and database information...")
    exports = cfn_client.list_exports()['Exports']
    export_map = {e['Name']: e['Value'] for e in exports}
    
    vpc_id = export_map.get('vibe-coding-VPC-ID')
    subnet_1 = export_map.get('vibe-coding-Pvt-Subnet-1')
    subnet_2 = export_map.get('vibe-coding-Pvt-Subnet-2')
    subnet_3 = export_map.get('vibe-coding-Pvt-Subnet-3')
    db_endpoint = export_map.get('vibe-coding-DB-Cluster-Endpoint')
    db_name = export_map.get('vibe-coding-DB-Name')
    db_secret_arn = export_map.get('vibe-coding-DB-Secret-ARN')
    
    print(f"VPC ID: {vpc_id}")
    print(f"Subnets: {subnet_1}, {subnet_2}, {subnet_3}")
    print(f"DB Endpoint: {db_endpoint}")
    print(f"DB Name: {db_name}")
    print(f"DB Secret ARN: {db_secret_arn}\n")

    # Step 6: Login to ECR
    print("Step 6: Logging in to ECR...")
    password = ecr_client.get_authorization_token()['authorizationData'][0]['authorizationToken']
    run_command(
        f"aws ecr get-login-password --region {REGION} --profile {PROFILE} | "
        f"docker login --username AWS --password-stdin {repository_uri}",
        shell=True
    )
    print("✓ Logged in to ECR\n")

    # Step 7: Build Docker image
    print("Step 7: Building Docker image for linux/amd64...")
    run_command(
        f"docker build --platform linux/amd64 -t {REPOSITORY_NAME}:latest -f ecs-deploy/Dockerfile .",
        shell=True
    )
    print("✓ Docker image built\n")

    # Step 8: Tag and push image
    print("Step 8: Tagging and pushing image to ECR...")
    run_command(f"docker tag {REPOSITORY_NAME}:latest {repository_uri}:latest", shell=True)
    run_command(f"docker push {repository_uri}:latest", shell=True)
    print("✓ Image pushed to ECR\n")

    # Step 9: Create ECS Express Gateway Service
    print("Step 9: Creating ECS Express Gateway Service with 3 replicas...")
    
    # Prepare the service configuration
    primary_container = {
        "image": f"{repository_uri}:latest",
        "containerPort": 8080,
        "environment": [
            {"name": "DB_HOST", "value": db_endpoint},
            {"name": "DB_NAME", "value": db_name},
            {"name": "DB_PORT", "value": "5432"}
        ],
        "secrets": [
            {"name": "DB_USERNAME", "valueFrom": f"{db_secret_arn}:username::"},
            {"name": "DB_PASSWORD", "valueFrom": f"{db_secret_arn}:password::"}
        ]
    }
    
    network_config = {
        "awsvpcConfiguration": {
            "subnets": [subnet_1, subnet_2, subnet_3],
            "assignPublicIp": "DISABLED"
        }
    }
    
    # Create the service
    try:
        response = ecs_client.create_express_gateway_service(
            cluster=CLUSTER_NAME,
            serviceName=SERVICE_NAME,
            executionRoleArn=execution_role_arn,
            infrastructureRoleArn=infrastructure_role_arn,
            taskRoleArn=task_role_arn,
            healthCheckPath="/health",
            primaryContainer=primary_container,
            networkConfiguration=network_config,
            cpu="512",
            memory="1024",
            scalingTarget={
                "desiredCount": 3,
                "minCapacity": 3,
                "maxCapacity": 6
            }
        )
        print("✓ ECS Express Gateway Service created with 3 replicas\n")
        print(f"Service ARN: {response['service']['serviceArn']}")
    except Exception as e:
        print(f"Error creating service: {e}")
        print("Falling back to AWS CLI method...\n")
        
        # Fallback to CLI
        with open('/tmp/primary-container.json', 'w') as f:
            json.dump(primary_container, f)
        with open('/tmp/network-config.json', 'w') as f:
            json.dump(network_config, f)
        
        run_command(
            f"aws ecs create-express-gateway-service "
            f"--cluster {CLUSTER_NAME} "
            f"--service-name {SERVICE_NAME} "
            f"--execution-role-arn {execution_role_arn} "
            f"--infrastructure-role-arn {infrastructure_role_arn} "
            f"--task-role-arn {task_role_arn} "
            f"--health-check-path /health "
            f"--primary-container file:///tmp/primary-container.json "
            f"--network-configuration file:///tmp/network-config.json "
            f"--cpu 512 "
            f"--memory 1024 "
            f"--scaling-target desiredCount=3,minCapacity=3,maxCapacity=6 "
            f"--profile {PROFILE} "
            f"--region {REGION}",
            shell=True
        )
        print("✓ Service created via CLI\n")

    # Step 10: Wait and get service URL
    print("Step 10: Waiting for service to stabilize...")
    time.sleep(10)
    
    try:
        service = ecs_client.describe_services(
            cluster=CLUSTER_NAME,
            services=[SERVICE_NAME]
        )['services'][0]
        
        print(f"Service Status: {service['status']}")
        print(f"Desired Count: {service['desiredCount']}")
        print(f"Running Count: {service['runningCount']}")
    except Exception as e:
        print(f"Could not retrieve service details: {e}")

    print()
    print("=" * 50)
    print("Deployment Complete!")
    print("=" * 50)
    print(f"Cluster: {CLUSTER_NAME}")
    print(f"Service: {SERVICE_NAME}")
    print(f"Replicas: 3")
    print(f"Repository: {repository_uri}")
    print()
    print("Check service status with:")
    print(f"aws ecs describe-services --cluster {CLUSTER_NAME} --services {SERVICE_NAME} --profile {PROFILE}")

if __name__ == "__main__":
    main()
