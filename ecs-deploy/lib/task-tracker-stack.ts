import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export class TaskTrackerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Create ECS Cluster
    const cluster = new ecs.Cluster(this, 'TaskTrackerCluster', {
      clusterName: 'task-tracker-cluster',
      enableFargateCapacityProviders: true,
    });

    // Create ECR Repository
    const repository = new ecr.Repository(this, 'TaskTrackerRepository', {
      repositoryName: 'task-tracker',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      emptyOnDelete: true,
      imageScanOnPush: true,
    });

    // Task Execution Role for ECS Express Mode
    // This role is used by ECS agent to pull images, write logs, and access secrets
    const taskExecutionRole = new iam.Role(this, 'ecsTaskTrackerExecutionRole', {
      roleName: 'ecsTaskTrackerExecutionRole',
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: 'Task execution role for ECS Express Mode - Task Tracker',
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonECSTaskExecutionRolePolicy'),
      ],
    });

    // Add permissions to read secrets from Secrets Manager
    taskExecutionRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'secretsmanager:GetSecretValue',
        'kms:Decrypt',
      ],
      resources: [
        `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`,
      ],
    }));

    // Infrastructure Role for ECS Express Mode
    // This role is used by ECS to create and manage AWS resources (ALB, security groups, etc.)
    const infrastructureRole = new iam.Role(this, 'ecsTaskTrackerInfrastructureRole', {
      roleName: 'ecsTaskTrackerInfrastructureRole',
      assumedBy: new iam.ServicePrincipal('ecs.amazonaws.com'),
      description: 'Infrastructure role for ECS Express Mode - Task Tracker',
    });

    // Add permissions for ECS Express Mode infrastructure management
    infrastructureRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        // Elastic Load Balancing permissions
        'elasticloadbalancing:CreateLoadBalancer',
        'elasticloadbalancing:CreateTargetGroup',
        'elasticloadbalancing:CreateListener',
        'elasticloadbalancing:CreateRule',
        'elasticloadbalancing:DeleteLoadBalancer',
        'elasticloadbalancing:DeleteTargetGroup',
        'elasticloadbalancing:DeleteListener',
        'elasticloadbalancing:DeleteRule',
        'elasticloadbalancing:Describe*',
        'elasticloadbalancing:ModifyLoadBalancerAttributes',
        'elasticloadbalancing:ModifyTargetGroup',
        'elasticloadbalancing:ModifyTargetGroupAttributes',
        'elasticloadbalancing:RegisterTargets',
        'elasticloadbalancing:DeregisterTargets',
        'elasticloadbalancing:AddTags',
        // EC2 permissions for security groups and networking
        'ec2:CreateSecurityGroup',
        'ec2:DeleteSecurityGroup',
        'ec2:Describe*',
        'ec2:AuthorizeSecurityGroupIngress',
        'ec2:AuthorizeSecurityGroupEgress',
        'ec2:RevokeSecurityGroupIngress',
        'ec2:RevokeSecurityGroupEgress',
        'ec2:CreateTags',
        // Application Auto Scaling permissions
        'application-autoscaling:RegisterScalableTarget',
        'application-autoscaling:DeregisterScalableTarget',
        'application-autoscaling:PutScalingPolicy',
        'application-autoscaling:DeleteScalingPolicy',
        'application-autoscaling:Describe*',
        // CloudWatch permissions for monitoring
        'cloudwatch:PutMetricAlarm',
        'cloudwatch:DeleteAlarms',
        'cloudwatch:Describe*',
        // IAM permissions for service-linked roles
        'iam:CreateServiceLinkedRole',
        'iam:PassRole',
      ],
      resources: ['*'],
    }));

    // Task Role for application to access AWS services
    // This role is used by the application code running in the container
    const taskRole = new iam.Role(this, 'ecsTaskTrackerTaskRole', {
      roleName: 'ecsTaskTrackerTaskRole',
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      description: 'Task role for Task Tracker application',
    });

    // Add permissions for the application to access other AWS services if needed
    taskRole.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents',
      ],
      resources: ['*'],
    }));

    // Outputs
    new cdk.CfnOutput(this, 'ClusterName', {
      value: cluster.clusterName,
      description: 'ECS Cluster Name',
      exportName: 'TaskTrackerClusterName',
    });

    new cdk.CfnOutput(this, 'RepositoryUri', {
      value: repository.repositoryUri,
      description: 'ECR Repository URI',
      exportName: 'TaskTrackerRepositoryUri',
    });

    new cdk.CfnOutput(this, 'RepositoryName', {
      value: repository.repositoryName,
      description: 'ECR Repository Name',
      exportName: 'TaskTrackerRepositoryName',
    });

    new cdk.CfnOutput(this, 'TaskExecutionRoleArn', {
      value: taskExecutionRole.roleArn,
      description: 'Task Execution Role ARN for ECS Express Mode',
      exportName: 'TaskTrackerExecutionRoleArn',
    });

    new cdk.CfnOutput(this, 'InfrastructureRoleArn', {
      value: infrastructureRole.roleArn,
      description: 'Infrastructure Role ARN for ECS Express Mode',
      exportName: 'TaskTrackerInfrastructureRoleArn',
    });

    new cdk.CfnOutput(this, 'TaskRoleArn', {
      value: taskRole.roleArn,
      description: 'Task Role ARN for application',
      exportName: 'TaskTrackerTaskRoleArn',
    });
  }
}
