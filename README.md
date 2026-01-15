# Task Tracker Application

A Flask-based task management application deployed on AWS ECS Fargate with Aurora PostgreSQL database.

## Architecture

- **Frontend**: Flask web application with HTML templates
- **Backend**: Python Flask REST API
- **Database**: Aurora PostgreSQL (existing `vibe-coding` stack)
- **Infrastructure**: AWS ECS Express Mode Deployment
- **Platform**: AMD64 Linux containers

## Features

- Create, view, and manage tasks
- Task completion tracking
- Due date management
- Health check endpoint (`/health`)
- Responsive web interface

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed and running
- Existing `vibe-coding` CloudFormation stack with VPC and Aurora database

## Deployment

The deployment is performed with Vibe Coding using Amazon Q CLI. Refer to the lab guide for instructions.