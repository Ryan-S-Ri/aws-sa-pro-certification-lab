# Exercise 2: Application Containerization

## Objective
Containerize a legacy application and deploy it to ECS Fargate.

## Prerequisites
- ECS cluster created
- Container registry available
- Sample application ready

## Duration
45 minutes

## Tasks

### Task 1: Create Dockerfile
```dockerfile
FROM node:14-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### Task 2: Build and Push Image
```bash
# Build Docker image
docker build -t my-app:latest .

# Tag for ECR
docker tag my-app:latest $(aws ecr get-login-password --region us-east-1).dkr.ecr.us-east-1.amazonaws.com/my-app:latest

# Push to ECR
docker push $(aws ecr get-login-password --region us-east-1).dkr.ecr.us-east-1.amazonaws.com/my-app:latest
```

### Task 3: Deploy to ECS
```bash
# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create service
aws ecs create-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service-name my-app \
  --task-definition my-app:1 \
  --desired-count 2 \
  --launch-type FARGATE
```

## Validation
- Container runs successfully
- Service is healthy in ECS
- Application accessible via load balancer
