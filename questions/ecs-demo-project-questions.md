# AWS ECS — Q&A 

> **Purpose:** This document contains commonly asked AWS ECS questions, production-oriented answers, architecture explanations, and troubleshooting approaches.

---

# 1. ECS Fundamentals

## Q1. What is Amazon ECS?

**Answer:**

Amazon ECS (Elastic Container Service) is a fully managed AWS container orchestration service used to run, manage, deploy, and scale containerized applications.

ECS manages the lifecycle of containers through concepts such as:

* ECS Cluster
* ECS Service
* ECS Task
* Task Definition
* Container

ECS can run containers using:

* **AWS Fargate**
* **Amazon EC2**

### Simple hierarchy

```text
AWS ECS
   │
   └── Cluster
        │
        ├── Service
        │    ├── Task
        │    ├── Task
        │    └── Task
        │
        └── Service
             ├── Task
             └── Task
```

---

# 2. ECS Cluster

## Q2. What is an ECS Cluster?

**Answer:**

An ECS cluster is a logical grouping of ECS services and tasks.

It provides the environment in which ECS workloads are managed.

For example:

```text
ECS Cluster
│
├── API Service
│   ├── Task 1
│   ├── Task 2
│   └── Task 3
│
├── Users Service
│   ├── Task 1
│   └── Task 2
│
└── Orders Service
    ├── Task 1
    └── Task 2
```

The cluster itself does not mean that all applications run in one container or one server.

---

# 3. ECS Task

## Q3. What is an ECS Task?

**Answer:**

An ECS Task is a running instance of a Task Definition.

For example:

```text
Task Definition
      │
      ▼
   Run Task
      │
      ▼
   ECS Task
      │
      ├── Application Container
      └── Sidecar Container
```

If the service has a desired count of 3:

```text
ECS Service
│
├── Task 1
├── Task 2
└── Task 3
```

Each task represents a running workload.

---

# 4. Task Definition

## Q4. What is an ECS Task Definition?

**Answer:**

A Task Definition is the blueprint that tells ECS how to run a containerized workload.

It defines things such as:

* Container image
* CPU
* Memory
* Container ports
* Environment variables
* Secrets
* IAM roles
* Logging configuration
* Health checks
* Volumes
* Container dependencies
* Network configuration

Example:

```text
Task Definition
│
├── Image: orders:v1
├── CPU: 512
├── Memory: 1024 MB
├── Port: 5002
├── Environment variables
├── Secrets
├── CloudWatch logging
└── Health check
```

A new Task Definition revision can be created whenever the configuration or container image changes.

---

# 5. ECS Service

## Q5. What is an ECS Service?

**Answer:**

An ECS Service is responsible for maintaining the desired number of tasks and managing their lifecycle.

For example:

```text
Desired Count = 3

ECS Service
│
├── Task 1
├── Task 2
└── Task 3
```

If Task 2 fails:

```text
Task 1
Task 2 ❌
Task 3
```

ECS Service detects that the desired count is no longer satisfied and launches a replacement:

```text
Task 1
Task 3
Task 4 ← Replacement
```

This provides task-level resiliency.

---

# 6. Fargate vs EC2

## Q6. What is the difference between ECS Fargate and ECS on EC2?

| Feature                   | Fargate                           | EC2                       |
| ------------------------- | --------------------------------- | ------------------------- |
| Infrastructure management | AWS manages it                    | Customer manages it       |
| EC2 instances             | No direct management              | Customer manages          |
| Scaling compute capacity  | AWS handles underlying capacity   | Customer manages capacity |
| OS management             | AWS                               | Customer                  |
| Infrastructure control    | Lower                             | Higher                    |
| Operational overhead      | Lower                             | Higher                    |
| Specialized hardware      | Limited compared with EC2 options | More flexibility          |

### Recommended explanation

> We use ECS with Fargate when we want to reduce infrastructure-management overhead and focus primarily on the containerized workload. ECS on EC2 would be more appropriate when we need greater control over the underlying compute layer, specific instance types, or specialized infrastructure requirements.

---

# 7. ECS Networking

## Q7. Does ECS run in public or private subnets?

**Answer:**

ECS itself is not simply classified as "public" or "private."

For Fargate, the ECS task receives networking through an ENI in the configured VPC subnet.

In a typical production architecture, ECS tasks are deployed in **private subnets**.

```text
VPC
│
├── Availability Zone 1
│   ├── Public Subnet
│   │   └── ALB
│   │
│   └── Private Subnet
│       └── ECS Tasks
│
└── Availability Zone 2
    ├── Public Subnet
    │   └── ALB
    │
    └── Private Subnet
        └── ECS Tasks
```

The ALB is exposed publicly, while the application containers remain private.

---

# 8. How Does a Request Reach ECS?

## Q8. How does traffic travel from the internet to an ECS container?

**Answer:**

A typical request flow is:

```text
Client
   │
   ▼
DNS
   │
   ▼
Application Load Balancer
   │
   ▼
Listener
   │
   ▼
Target Group
   │
   ▼
ECS Task ENI
   │
   ▼
Container
   │
   ▼
Application
```

Example:

```text
api.example.com
       │
       ▼
      ALB
       │
       ▼
API Target Group
       │
       ▼
ECS API Service
       │
       ▼
API Container :5000
```

The ALB sends traffic to healthy targets registered in the target group.

---

# 9. ALB and ECS

## Q9. How does an ALB integrate with ECS?

**Answer:**

The ALB forwards requests to a Target Group.

The ECS Service associates its tasks with that Target Group.

```text
ALB
 │
 ├── Listener :443
 │
 ▼
Target Group
 │
 ├── Task IP 1
 ├── Task IP 2
 └── Task IP 3
```

With the `awsvpc` networking model commonly used with Fargate, each task gets its own ENI/IP address.

The ALB uses health checks to determine whether a task should receive traffic.

---

# 10. Security Groups

## Q10. How would you configure Security Groups for ECS?

**Answer:**

A common production design is:

```text
Internet
   │
   ▼
ALB Security Group
   │
   │ TCP 443
   ▼
ECS Security Group
   │
   │ Application Port
   ▼
ECS Container
```

### ALB Security Group

```text
Inbound:
443 from Internet

Outbound:
ECS Security Group
```

### ECS Security Group

```text
Inbound:
Application port from ALB Security Group

Outbound:
Required destinations
```

The ECS application should not normally expose its application port directly to the internet.

---

# 11. High Availability

## Q11. How do you achieve High Availability in ECS?

**Answer:**

We achieve HA by distributing ECS tasks across multiple Availability Zones and maintaining multiple task replicas.

Example:

```text
                    ALB
                 /       \
                /         \
             AZ-1         AZ-2
              │             │
           Task 1          Task 2
           Task 3          Task 4
```

If one task fails, ECS can replace it.

If one Availability Zone has an issue, tasks in another AZ can continue serving traffic, assuming sufficient capacity and appropriate architecture.

Key components:

* Multiple Availability Zones
* Multiple ECS tasks
* ALB
* Health checks
* ECS Service desired count
* Auto Scaling

---

# 12. ECS Auto Scaling

## Q12. How does ECS perform Auto Scaling?

**Answer:**

ECS Service Auto Scaling changes the number of running tasks based on scaling policies.

Example:

```text
CPU Utilization > 70%
        │
        ▼
Scale Out
        │
        ▼
2 Tasks → 4 Tasks
```

When demand decreases:

```text
CPU Utilization decreases
        │
        ▼
Scale In
        │
        ▼
4 Tasks → 2 Tasks
```

Scaling can be based on metrics such as:

* CPU utilization
* Memory utilization
* ALB request count per target
* Custom CloudWatch metrics

---

# 13. Service Scaling vs EC2 Scaling

## Q13. What is the difference between ECS Service Auto Scaling and EC2 Auto Scaling?

**Answer:**

They operate at different layers.

### ECS Service Auto Scaling

Changes:

```text
Number of ECS Tasks
```

Example:

```text
2 Tasks → 5 Tasks
```

### EC2 Auto Scaling

Relevant when ECS uses EC2 capacity.

Changes:

```text
Number of EC2 Instances
```

Example:

```text
3 EC2 instances → 6 EC2 instances
```

With Fargate, we don't manage the underlying EC2 capacity ourselves.

---

# 14. Deployment Flow

## Q14. How would you deploy a new container version?

**Answer:**

A typical CI/CD flow is:

```text
Developer
   │
   ▼
GitHub
   │
   ▼
GitHub Actions
   │
   ├── Build
   ├── Test
   ├── Docker Build
   └── Push Image
          │
          ▼
         ECR
          │
          ▼
New Task Definition Revision
          │
          ▼
ECS Service
          │
          ▼
New ECS Tasks
```

Example:

```text
orders:v1
     │
     ▼
orders:v2
```

The ECS Service deploys tasks using the new Task Definition revision.

---

# 15. CI vs CD

## Q15. Does CI deploy directly to ECS?

**Answer:**

CI and CD should be considered separate responsibilities.

### CI

```text
Source Code
     ↓
Build
     ↓
Test
     ↓
Docker Image
     ↓
ECR
```

### CD

```text
ECR Image
     ↓
Task Definition Revision
     ↓
ECS Service
     ↓
Deployment
```

An organization may introduce manual approval between CI and CD depending on its release process.

---

# 16. Rolling Deployment

## Q16. How does a rolling deployment work in ECS?

**Answer:**

A rolling deployment gradually replaces old tasks with new tasks.

Example:

```text
Initial:

Task A - v1
Task B - v1
Task C - v1
```

During deployment:

```text
Task A - v1
Task B - v1
Task C - v1
Task D - v2
```

Then:

```text
Task A - v1
Task C - v1
Task D - v2
Task E - v2
```

Eventually:

```text
Task D - v2
Task E - v2
Task F - v2
```

The exact replacement behavior is controlled by ECS deployment configuration.

---

# 17. Blue/Green Deployment

## Q17. What is Blue/Green deployment?

**Answer:**

Blue/Green maintains two application versions.

```text
BLUE
v1
v1
v1

GREEN
v2
v2
v2
```

Traffic can be shifted from Blue to Green after the new version has been validated.

Benefits:

* Safer deployments
* Easier rollback
* Ability to test the new version before full traffic migration

---

# 18. Sidecar Containers

## Q18. Does ECS support sidecar containers?

**Answer:**

Yes.

Multiple containers can be defined within the same ECS Task Definition.

Example:

```text
ECS Task
│
├── Application Container
│
└── Sidecar Container
```

Possible sidecar use cases include:

* Logging
* Monitoring
* Telemetry
* Proxy
* Security agents
* Supporting processes

The containers in the same task can share the task's networking context.

---

# 19. Does ECS Have Init Containers?

## Q19. Does ECS have an init container like Kubernetes?

**Answer:**

ECS does not provide a direct equivalent to the Kubernetes `initContainer` concept.

However, similar initialization workflows can be implemented using ECS features and application patterns.

Possible approaches include:

* Entrypoint/startup scripts
* Separate ECS tasks
* Container dependency conditions
* EventBridge-triggered jobs
* Application initialization logic

For example:

```text
Initialization Container
        │
        │ SUCCESS
        ▼
Application Container
```

ECS supports container dependency conditions, but this should not be described as exactly equivalent to Kubernetes init containers.

---

# 20. Scheduled Jobs / Cron

## Q20. Can ECS run Cron jobs?

**Answer:**

Yes.

For scheduled workloads, a common pattern is to use EventBridge Scheduler or EventBridge Rules to launch an ECS task.

```text
EventBridge
     │
     │ Schedule: Every day 02:00
     ▼
Run ECS Task
     │
     ▼
Fargate Task
     │
     ▼
Cron Job
     │
     ▼
Complete
     │
     ▼
Task Stops
```

This is different from an ECS Service.

### ECS Service

Designed to keep the desired number of tasks running.

### Scheduled ECS Task

Designed to execute a workload and then terminate.

---

# 21. ECS Logging

## Q21. Where do ECS container logs go?

**Answer:**

A common architecture is:

```text
Application
     │
     ▼
stdout / stderr
     │
     ▼
ECS Logging Driver
     │
     ▼
CloudWatch Logs
```

For more advanced logging architectures, FireLens can be used to route logs to other destinations.

Containers are ephemeral, so applications should not depend on local container storage as the primary location for persistent logs.

---

# 22. Secrets Management

## Q22. How do you manage secrets in ECS?

**Answer:**

Sensitive values should not be hardcoded into Docker images or source code.

A typical approach is:

```text
AWS Secrets Manager
        │
        ▼
ECS Task
        │
        ▼
Application
```

SSM Parameter Store can also be used for configuration and secrets depending on the requirement.

Access should be controlled using IAM permissions.

---

# 23. Task Execution Role vs Task Role

## Q23. What is the difference between Task Execution Role and Task Role?

**Answer:**

This is an important distinction.

### Task Execution Role

Used by ECS/Fargate for task startup and infrastructure-related operations.

Examples:

* Pulling images from ECR
* Sending logs to CloudWatch
* Retrieving certain startup resources

### Task Role

Used by the application running inside the container.

Example:

```text
Application
     │
     ▼
AWS SDK
     │
     ▼
Task Role
     │
     ├── S3
     ├── DynamoDB
     └── SQS
```

Simple rule:

> **Execution Role = ECS needs it**

> **Task Role = Application needs it**

---

# 24. ECS Troubleshooting

## Q24. ECS Service is running, but the application is not accessible. How would you troubleshoot?

**Answer:**

I would troubleshoot from the request path rather than randomly changing configurations.

```text
Client
 ↓
DNS
 ↓
ALB
 ↓
Listener
 ↓
Target Group
 ↓
ECS Task
 ↓
Container
 ↓
Application
```

### Step 1 — DNS

Verify that DNS points to the correct ALB.

### Step 2 — ALB Listener

Verify the listener configuration.

Example:

```text
HTTPS :443
     ↓
Target Group
```

### Step 3 — Target Group

Check target health.

```text
Healthy
Healthy
Healthy
```

If targets are unhealthy, investigate:

* Health check path
* Health check port
* Security groups
* Application availability
* Container port

### Step 4 — Security Groups

Verify:

```text
ALB SG
   ↓
ECS SG
```

The ECS security group should allow the application port from the ALB security group.

### Step 5 — Container Port

Verify that the container is actually listening on the expected port.

Example:

```text
Application → 5000
Target Group → 8080
```

This could cause the health check to fail.

### Step 6 — Application Binding

For applications such as Flask, verify that the application is listening on:

```text
0.0.0.0
```

rather than only:

```text
127.0.0.1
```

### Step 7 — Logs

Check CloudWatch Logs for:

* Application startup failures
* Dependency errors
* Configuration issues
* Port errors
* Runtime exceptions

---

# 25. What Happens When an ECS Task Crashes?

## Q25. What happens if an ECS task crashes?

**Answer:**

If the task is managed by an ECS Service, ECS attempts to maintain the configured desired count.

Example:

```text
Desired Count = 3

Task 1
Task 2 ❌
Task 3
```

ECS launches a replacement:

```text
Task 1
Task 3
Task 4 ← Replacement
```

The failed task may also generate events/logs that can be used for troubleshooting.

---

# 26. ECS vs EKS

## Q26. Why would you choose ECS instead of EKS?

**Answer:**

ECS is generally simpler when the organization primarily needs container orchestration without requiring the Kubernetes ecosystem.

### ECS advantages

* AWS-native orchestration
* Simpler operational model
* Strong Fargate integration
* Less Kubernetes administration
* Tight AWS integration

### EKS advantages

* Kubernetes ecosystem
* Kubernetes APIs and tooling
* Large ecosystem of Kubernetes operators/controllers
* Portability across Kubernetes environments
* Advanced Kubernetes-native capabilities

A good client-facing answer is:

> "The choice depends on the operational and application requirements. If the workload primarily needs AWS-native container orchestration with lower operational overhead, ECS is a strong fit. If the organization specifically needs Kubernetes APIs, ecosystem tooling, or Kubernetes-native platform capabilities, EKS may be more appropriate."

---

# 27. Communication — When You Don't Know the Answer

Never guess an AWS implementation detail.

### Avoid

> "I think ECS probably supports that."

### Better

> "I would want to validate the exact ECS behavior before confirming that. Conceptually, we can achieve the requirement through X, but I don't want to give you an inaccurate implementation detail."

### Another good response

> "There are two possible approaches here. The right choice depends on whether the requirement is X or Y. I would first clarify that requirement and then select the appropriate ECS pattern."

This demonstrates technical maturity rather than weakness.

---

# 28. Production ECS Architecture — Quick Reference

```text
                         Internet
                            │
                            ▼
                         Route 53
                            │
                            ▼
                     Application Load Balancer
                            │
                     ┌──────┼──────┐
                     ▼      ▼      ▼
                   API TG Users TG Orders TG
                     │      │      │
                     ▼      ▼      ▼
                   ECS Services
                     │      │      │
                ┌────┴─┐ ┌──┴──┐ ┌─┴────┐
                │Tasks │ │Tasks│ │Tasks │
                └──────┘ └─────┘ └──────┘
                     │
                     ▼
                Private Subnets
                     │
             ┌───────┼────────┐
             ▼       ▼        ▼
            RDS   DynamoDB    S3
```

Supporting components:

```text
ECR
 │
 └── Container Images

CloudWatch
 │
 ├── Logs
 ├── Metrics
 └── Alarms

Secrets Manager / SSM
 │
 └── Configuration & Secrets

IAM
 │
 ├── Task Execution Role
 └── Task Role

EventBridge
 │
 └── Scheduled ECS Tasks
```

---

# 29. Important ECS Concepts to Remember
Make sure you can explain these without referring to documentation:

* ECS Cluster
* ECS Service
* ECS Task
* Task Definition
* Fargate
* ECS on EC2
* `awsvpc`
* ENI
* ALB
* Target Group
* Health Check
* Security Groups
* IAM Task Role
* IAM Execution Role
* ECR
* CloudWatch Logs
* ECS Service Auto Scaling
* Rolling Deployment
* Blue/Green Deployment
* EventBridge scheduled tasks
* Sidecar containers
* Container dependencies
* Private subnets
* NAT Gateway
* VPC Endpoints
* Service Discovery
* ECS troubleshooting

---

# 30. Recommended Answer Pattern

For architecture questions, use this structure:

```text
1. Direct Answer
       ↓
2. Explain Why
       ↓
3. Explain How
       ↓
4. Mention Trade-off / Alternative
```

Example:

### Client

> Why are ECS tasks in private subnets?

### Strong Answer

> "We place the ECS tasks in private subnets to avoid exposing the application containers directly to the internet."

Then:

> "External traffic comes through the public ALB, which forwards traffic to healthy ECS tasks."

Then:

```text
Internet
   ↓
Public ALB
   ↓
Private ECS Tasks
```

Then mention:

> "For outbound connectivity, we can use NAT Gateway where internet access is required, and VPC endpoints for supported AWS services to reduce unnecessary internet/NAT traffic."

This gives the client both the **decision and the reasoning**.

---

# 31. Quick ECS Request Flow

Remember this single flow:

```text
User
 ↓
Route 53
 ↓
ALB
 ↓
Listener
 ↓
Target Group
 ↓
ECS Service
 ↓
ECS Task
 ↓
Container
 ↓
Application
```

And for deployment:

```text
Developer
 ↓
GitHub
 ↓
CI
 ↓
Docker Image
 ↓
ECR
 ↓
Task Definition Revision
 ↓
ECS Service
 ↓
New Tasks
```

And for scheduled jobs:

```text
EventBridge
 ↓
ECS RunTask
 ↓
Fargate Task
 ↓
Job
 ↓
Task Stops
```

---

# 32. Final Principle

For any scenario question, don't answer only with **what ECS does**.

Always be prepared to explain:

> **What → Why → How → Trade-off**

For example:

```text
WHAT:
We use ECS Fargate.

WHY:
To reduce infrastructure-management overhead.

HOW:
Tasks run in private subnets and are exposed through an ALB.

TRADE-OFF:
Fargate provides less underlying infrastructure control than ECS on EC2.
```

This transforms an AWS definition into an **architecture-level answer**.
