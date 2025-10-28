# WebSocket Server Deployment on AWS

## Overview

Deploying a WebSocket server on AWS requires careful consideration of infrastructure components that support persistent, bidirectional connections. Unlike traditional HTTP request/response patterns, WebSockets maintain long-lived connections.

---

## Architecture Options

### Option 1: API Gateway WebSocket API (Recommended for Serverless)

**Components:**
- **AWS API Gateway** (WebSocket APIs)
- **AWS Lambda** (connection handlers)
- **Amazon DynamoDB** (connection tracking)
- **Amazon EventBridge or SNS** (event broadcasting)

**Pros:**
- ✅ Fully managed and serverless
- ✅ Auto-scaling built-in
- ✅ Pay-per-use pricing model
- ✅ No server management
- ✅ Integrated with AWS ecosystem

**Cons:**
- ❌ 10-minute connection timeout (Lambda limit)
- ❌ Cold start latency for Lambda functions
- ❌ More complex for simple use cases
- ❌ Limited to 128KB message size

**Cost Structure:**
- $1.00 per million messages
- $0.25 per million connection minutes
- Lambda invocation costs
- DynamoDB read/write costs

**Best For:**
- Variable/unpredictable traffic
- Serverless-first architecture
- Budget-conscious projects
- Quick prototyping

---

### Option 2: Application Load Balancer + EC2/ECS (Recommended for Traditional Apps)

**Components:**
- **Application Load Balancer (ALB)** with WebSocket support
- **Amazon EC2** or **ECS/Fargate** (Go WebSocket server)
- **Amazon ElastiCache Redis** (connection state & pub/sub)
- **Amazon RDS** or Aurora (persistent data)
- **Auto Scaling Groups** (for EC2) or ECS Service Auto Scaling

**Pros:**
- ✅ No connection timeout limits
- ✅ Full control over WebSocket implementation
- ✅ Better for long-lived connections
- ✅ Simpler codebase (standard Go server)
- ✅ Supports larger message sizes

**Cons:**
- ❌ Must manage server instances
- ❌ Fixed baseline costs
- ❌ Requires capacity planning
- ❌ More DevOps overhead

**Cost Structure:**
- ALB: ~$16-22/month + $0.008/LCU-hour
- EC2: ~$30-400/month depending on instance type
- ElastiCache Redis: ~$15-200/month depending on node type
- Data transfer costs

**Best For:**
- Predictable traffic patterns
- Long-lived connections (>10 minutes)
- Existing EC2/ECS infrastructure
- Need for full control

---

### Option 3: Network Load Balancer + ECS/EKS (High Performance)

**Components:**
- **Network Load Balancer (NLB)** (Layer 4)
- **Amazon ECS on Fargate** or **EKS** (Kubernetes)
- **Amazon ElastiCache Redis Cluster** (distributed state)
- **Application Auto Scaling**

**Pros:**
- ✅ Ultra-low latency
- ✅ Handles millions of connections
- ✅ Static IP addresses
- ✅ Better for high-throughput scenarios

**Cons:**
- ❌ More expensive than ALB
- ❌ Less application-level features
- ❌ More complex setup

**Best For:**
- High-performance requirements
- Very large scale (>100K concurrent connections)
- Low-latency critical applications

---

## Detailed Architecture: ALB + ECS (Recommended)

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                         CloudFront (Optional CDN)            │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    Route 53 (DNS)                            │
│                  ws.delivery-app.com                         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│              Application Load Balancer (ALB)                 │
│                    - WebSocket Support                       │
│                    - SSL/TLS Termination                     │
│                    - Health Checks                           │
└──────────┬────────────────────────────┬─────────────────────┘
           │                            │
    ┌──────▼──────┐            ┌───────▼────────┐
    │   ECS Task  │            │   ECS Task     │
    │   (Fargate) │            │   (Fargate)    │
    │             │            │                │
    │ Go WebSocket│            │ Go WebSocket   │
    │   Server    │            │   Server       │
    └──────┬──────┘            └───────┬────────┘
           │                            │
           └──────────┬─────────────────┘
                      │
        ┌─────────────▼──────────────────────────┐
        │    ElastiCache Redis Cluster           │
        │    - Connection State Storage          │
        │    - Pub/Sub for Broadcasting          │
        │    - Session Management                │
        └─────────────┬──────────────────────────┘
                      │
        ┌─────────────▼──────────────────────────┐
        │         Amazon RDS PostgreSQL          │
        │         - Orders Database              │
        │         - User Data                    │
        └────────────────────────────────────────┘
```

---

## Implementation Guide

### 1. VPC Setup

```hcl
# Terraform example
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "delivery-app-vpc"
  }
}

# Public subnets for ALB
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true
}

# Private subnets for ECS tasks
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}
```

### 2. Application Load Balancer

```hcl
resource "aws_lb" "websocket" {
  name               = "delivery-app-ws-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = true
  enable_http2              = true
}

resource "aws_lb_target_group" "websocket" {
  name        = "ws-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  # Important for WebSocket connections
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = true
  }
}

resource "aws_lb_listener" "websocket_https" {
  load_balancer_arn = aws_lb.websocket.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.websocket.arn
  }
}
```

### 3. ECS Service with Fargate

```hcl
resource "aws_ecs_cluster" "main" {
  name = "delivery-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "websocket" {
  family                   = "websocket-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"   # 0.5 vCPU
  memory                   = "1024"  # 1 GB
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "websocket-server"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.redis.cache_nodes[0].address
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://..."  # Use Secrets Manager in production
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.websocket.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "websocket"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

resource "aws_ecs_service" "websocket" {
  name            = "websocket-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.websocket.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.websocket.arn
    container_name   = "websocket-server"
    container_port   = 8080
  }

  # Auto-scaling configuration
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  depends_on = [aws_lb_listener.websocket_https]
}
```

### 4. ElastiCache Redis Setup

```hcl
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "delivery-app-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"  # Start small, scale up
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  # For production: use replication group instead
  # snapshot_retention_limit = 5
  # snapshot_window         = "03:00-05:00"
}

# For production with high availability:
resource "aws_elasticache_replication_group" "redis_ha" {
  replication_group_id       = "delivery-app-redis-cluster"
  replication_group_description = "Redis cluster for WebSocket state"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = "cache.r6g.large"
  num_cache_clusters         = 3  # 1 primary + 2 replicas
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = true
  multi_az_enabled          = true

  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
}
```

### 5. Auto Scaling Configuration

```hcl
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.websocket.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on CPU utilization
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Scale based on memory utilization
resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# Custom metric: Scale based on active connections
resource "aws_appautoscaling_policy" "ecs_connections" {
  name               = "connections-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "ActiveWebSocketConnections"
      namespace   = "DeliveryApp"
      statistic   = "Average"
    }
    target_value = 1000.0  # Scale when >1000 connections per task
  }
}
```

### 6. Security Groups

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Redis Security Group
resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Security group for Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "Redis from ECS tasks"
  }
}
```

---

## Go WebSocket Server Implementation

### Basic WebSocket Server with Redis Pub/Sub

```go
package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
    "sync"
    "time"

    "github.com/go-redis/redis/v8"
    "github.com/gorilla/websocket"
)

var (
    upgrader = websocket.Upgrader{
        CheckOrigin: func(r *http.Request) bool {
            // Configure allowed origins properly in production
            return true
        },
    }

    redisClient *redis.Client
    ctx         = context.Background()
)

type ConnectionManager struct {
    connections map[string]*websocket.Conn
    mutex       sync.RWMutex
}

var manager = &ConnectionManager{
    connections: make(map[string]*websocket.Conn),
}

type Message struct {
    Type      string      `json:"type"`
    Payload   interface{} `json:"payload"`
    Timestamp time.Time   `json:"timestamp"`
}

func main() {
    // Initialize Redis
    redisClient = redis.NewClient(&redis.Options{
        Addr:     "redis:6379", // Use ElastiCache endpoint
        Password: "",
        DB:       0,
    })

    // Start Redis subscriber
    go subscribeToRedis()

    // WebSocket endpoint
    http.HandleFunc("/ws", handleWebSocket)

    // Health check endpoint (required for ALB)
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("healthy"))
    })

    log.Println("WebSocket server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
    // Upgrade HTTP connection to WebSocket
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Printf("WebSocket upgrade error: %v", err)
        return
    }
    defer conn.Close()

    // Get user/driver ID from JWT token (implement auth)
    userID := getUserIDFromRequest(r)

    // Register connection
    manager.mutex.Lock()
    manager.connections[userID] = conn
    manager.mutex.Unlock()

    // Store connection in Redis for distributed tracking
    redisClient.Set(ctx, "ws:"+userID, time.Now().Unix(), 24*time.Hour)

    defer func() {
        manager.mutex.Lock()
        delete(manager.connections, userID)
        manager.mutex.Unlock()
        redisClient.Del(ctx, "ws:"+userID)
    }()

    log.Printf("Driver %s connected", userID)

    // Send initial message
    sendMessage(conn, Message{
        Type:      "connected",
        Payload:   map[string]string{"user_id": userID},
        Timestamp: time.Now(),
    })

    // Listen for messages from client
    for {
        var msg Message
        err := conn.ReadJSON(&msg)
        if err != nil {
            if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
                log.Printf("WebSocket error: %v", err)
            }
            break
        }

        handleClientMessage(userID, msg)
    }
}

func subscribeToRedis() {
    pubsub := redisClient.Subscribe(ctx, "order:notifications")
    defer pubsub.Close()

    ch := pubsub.Channel()

    for msg := range ch {
        var notification Message
        if err := json.Unmarshal([]byte(msg.Payload), &notification); err != nil {
            log.Printf("Error unmarshaling notification: %v", err)
            continue
        }

        // Broadcast to specific users or all connected users
        broadcastMessage(notification)
    }
}

func broadcastMessage(msg Message) {
    manager.mutex.RLock()
    defer manager.mutex.RUnlock()

    for userID, conn := range manager.connections {
        err := sendMessage(conn, msg)
        if err != nil {
            log.Printf("Error sending to %s: %v", userID, err)
        }
    }
}

func sendMessage(conn *websocket.Conn, msg Message) error {
    conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
    return conn.WriteJSON(msg)
}

func getUserIDFromRequest(r *http.Request) string {
    // Extract from JWT token in query param or header
    token := r.URL.Query().Get("token")
    // Validate and decode JWT (implement proper auth)
    return token // Placeholder
}

func handleClientMessage(userID string, msg Message) {
    log.Printf("Received from %s: %+v", userID, msg)

    // Handle different message types
    switch msg.Type {
    case "ping":
        // Keep-alive
        redisClient.Set(ctx, "ws:"+userID, time.Now().Unix(), 24*time.Hour)
    case "location_update":
        // Store driver location
        // ... implementation
    }
}

// Publish notification from API server
func PublishOrderNotification(orderID int) {
    msg := Message{
        Type: "new_order",
        Payload: map[string]interface{}{
            "order_id": orderID,
            "action":   "available",
        },
        Timestamp: time.Now(),
    }

    data, _ := json.Marshal(msg)
    redisClient.Publish(ctx, "order:notifications", data)
}
```

---

## Monitoring & Observability

### CloudWatch Metrics

```hcl
resource "aws_cloudwatch_log_group" "websocket" {
  name              = "/ecs/websocket-server"
  retention_in_days = 7
}

# Custom metric for active connections
resource "aws_cloudwatch_log_metric_filter" "active_connections" {
  name           = "ActiveWebSocketConnections"
  log_group_name = aws_cloudwatch_log_group.websocket.name
  pattern        = "[time, request_id, level, msg=\"Driver * connected\"]"

  metric_transformation {
    name      = "ActiveWebSocketConnections"
    namespace = "DeliveryApp"
    value     = "1"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "websocket" {
  dashboard_name = "websocket-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }],
            ["DeliveryApp", "ActiveWebSocketConnections", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "WebSocket Metrics"
        }
      }
    ]
  })
}

# Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "websocket-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

## Cost Estimation (Monthly)

### Small Scale (< 1,000 concurrent connections)
- **ALB**: $22 + ~$5 LCU = **$27**
- **ECS Fargate (2 tasks, 0.5 vCPU, 1GB)**: 2 × $14.60 = **$29**
- **ElastiCache Redis (t3.micro)**: **$12**
- **Data Transfer**: ~**$10**
- **CloudWatch Logs**: ~**$5**
- **Total**: **~$83/month**

### Medium Scale (1,000 - 10,000 concurrent connections)
- **ALB**: $22 + ~$25 LCU = **$47**
- **ECS Fargate (5 tasks, 1 vCPU, 2GB)**: 5 × $42 = **$210**
- **ElastiCache Redis (r6g.large cluster)**: **$350**
- **Data Transfer**: ~**$50**
- **CloudWatch**: ~**$20**
- **Total**: **~$677/month**

### Large Scale (10,000+ concurrent connections)
- **ALB**: $22 + ~$100 LCU = **$122**
- **ECS Fargate (20 tasks, 2 vCPU, 4GB)**: 20 × $126 = **$2,520**
- **ElastiCache Redis (r6g.xlarge cluster)**: **$700**
- **Data Transfer**: ~**$200**
- **CloudWatch**: ~**$50**
- **Total**: **~$3,592/month**

---

## Best Practices

### 1. Connection Management
- Implement heartbeat/ping-pong to detect dead connections
- Set read/write deadlines on WebSocket connections
- Gracefully handle reconnections with exponential backoff
- Store connection metadata in Redis with TTL

### 2. Message Broadcasting
- Use Redis Pub/Sub for cross-instance messaging
- Implement message batching for efficiency
- Add message acknowledgment for critical updates
- Use Redis Streams for guaranteed delivery

### 3. Security
- Validate JWT tokens on WebSocket upgrade
- Use WSS (WebSocket Secure) only
- Implement rate limiting per connection
- Validate all incoming message payloads
- Use AWS WAF on ALB to prevent DDoS

### 4. Scalability
- Design stateless WebSocket handlers
- Store all state in Redis (not in-memory)
- Use connection pooling for database
- Implement graceful shutdown for zero-downtime deploys
- Use sticky sessions on ALB

### 5. Reliability
- Implement circuit breakers for downstream services
- Add retry logic with exponential backoff
- Monitor connection churn rate
- Set up health checks properly
- Use multi-AZ deployments

---

## Alternative: API Gateway WebSocket API

### Quick Setup Example

```yaml
# serverless.yml
service: delivery-websocket

provider:
  name: aws
  runtime: go1.x
  stage: ${opt:stage, 'dev'}
  region: us-east-1

  websocketsApiRouteSelectionExpression: $request.body.action

  environment:
    CONNECTIONS_TABLE: ${self:service}-${self:provider.stage}-connections

  iamRoleStatements:
    - Effect: Allow
      Action:
        - dynamodb:PutItem
        - dynamodb:GetItem
        - dynamodb:DeleteItem
        - dynamodb:Scan
      Resource:
        - !GetAtt ConnectionsTable.Arn

functions:
  connectionHandler:
    handler: bin/connection
    events:
      - websocket:
          route: $connect
      - websocket:
          route: $disconnect

  defaultHandler:
    handler: bin/default
    events:
      - websocket:
          route: $default

  sendMessage:
    handler: bin/sendmessage
    events:
      - websocket:
          route: sendmessage

resources:
  Resources:
    ConnectionsTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:provider.environment.CONNECTIONS_TABLE}
        AttributeDefinitions:
          - AttributeName: connectionId
            AttributeType: S
        KeySchema:
          - AttributeName: connectionId
            KeyType: HASH
        BillingMode: PAY_PER_REQUEST
```

**Pros of API Gateway approach:**
- Zero infrastructure management
- Automatic scaling
- Built-in connection management
- Pay only for what you use

**Cons:**
- 10-minute timeout limit
- 128KB message size limit
- Less control over connection lifecycle
- Cold start latency

---

## Deployment Checklist

- [ ] Set up VPC with public and private subnets
- [ ] Configure NAT Gateway for private subnet internet access
- [ ] Create SSL certificate in ACM for wss:// endpoint
- [ ] Set up Application Load Balancer with HTTPS listener
- [ ] Configure ECS cluster and task definition
- [ ] Deploy ElastiCache Redis cluster
- [ ] Set up IAM roles for ECS tasks
- [ ] Configure security groups with least privilege
- [ ] Set up CloudWatch logging and monitoring
- [ ] Configure auto-scaling policies
- [ ] Set up CloudWatch alarms for critical metrics
- [ ] Implement health check endpoint
- [ ] Test WebSocket connection and reconnection
- [ ] Load test with expected concurrent users
- [ ] Set up CI/CD pipeline for deployments
- [ ] Document WebSocket API protocol
- [ ] Configure Route 53 for custom domain
- [ ] Enable AWS WAF for DDoS protection (optional)
- [ ] Set up backup and disaster recovery plan

---

## Resources

- [AWS ALB WebSocket Support](https://aws.amazon.com/blogs/aws/new-aws-application-load-balancer/)
- [API Gateway WebSocket APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-websocket-api.html)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [ElastiCache for Redis](https://aws.amazon.com/elasticache/redis/)
- [Gorilla WebSocket](https://github.com/gorilla/websocket)

---

*Last Updated: 2025-10-26*
