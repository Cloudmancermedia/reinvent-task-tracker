# Best Practices

## General best practices
- Do not assume. If under confusion, as the user explicitly
- Only create the resources as requested by user
- Always use ECS MCP server. 
- Do not inject secrets in plain text. Use the Secrets Manager ARN reference
- Always build images for linux/amd64 platform
- Use public ECR repository: `public.ecr.aws/docker/library/`
- Expose application on port 8080
- Always run the application as non-root user.
- Always create IAM roles with name beginning with ecsTaskTracker

## ECS Express Mode best practives
- Review the ECS Express Mode documentation from ECS MCP server when creating IAM Roles.
- When creating IAM roles for ECS Express Mode, verify the managed policies from ECS MCP documentation
- MANDATORY: When creating deployment scripts for ECS Express Gateway Service, always validate the correctness of the parameters against the official CLI documentation - `https://docs.aws.amazon.com/cli/latest/reference/ecs/create-express-gateway-service.html`. Do not proceed with script generation until documentation is validated
- Always run --generate-cli-skeleton input first to see the exact parameter types
- Read the official CLI documentation before writing any AWS CLI commands

## Existing resource references
- The core resources like VPC, Subnets and Aurora PostgreSQL database are already created through 'vibe-coding' Cloudformation stack. 
- The Aurora Database name and the database endpoint are in the Cloudformation stack.
- The Aurora Database username and password are stored in AWS Secrets Manager. The ARN of the Secrets Manager is in the same stack. Pass the credentials as secrets.
- The following are the CloudFormation export names that you can refer to : vibe-coding-DB-Cluster-Endpoint, vibe-coding-DB-Name, vibe-coding-DB-Secret-ARN, vibe-coding-Pvt-Subnet-1, vibe-coding-Pvt-Subnet-2, vibe-coding-Pvt-Subnet-3, vibe-coding-Pub-Subnet1, vibe-coding-Pub-Subnet2, vibe-coding-Pub-Subnet3, vibe-coding-VPC-ID

## Output files location
- Create all output files in the folder name 'ecs-deploy' within the root of the project.
- Give the command to execute the shell script from project root.  In the shell script, reference the template from project directory
- Additionally generate the tear down scripts.
- Do not run the generated shell scripts automatically. Give the command to end user to run these
