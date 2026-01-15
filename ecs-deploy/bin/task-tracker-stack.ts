#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { TaskTrackerStack } from '../lib/task-tracker-stack';

const app = new cdk.App();
new TaskTrackerStack(app, 'TaskTrackerStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
  },
  description: 'Task Tracker ECS Express Mode Infrastructure',
});
