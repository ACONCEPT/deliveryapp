# Scheduled Jobs for Serverless Architecture

## Overview

This document explains how to implement scheduled jobs for the delivery app when running the backend API serverlessly (AWS Lambda, Google Cloud Functions, etc.). Since serverless functions only run on-demand, we need alternative solutions for recurring tasks.

## Table of Contents

1. [Recommended Solution: pg_cron](#recommended-solution-pg_cron)
2. [Alternative: Cloud Provider Schedulers](#alternative-cloud-provider-schedulers)
3. [Implementation Examples](#implementation-examples)
4. [Common Scheduled Tasks](#common-scheduled-tasks)

---

## Recommended Solution: pg_cron

### What is pg_cron?

pg_cron is a PostgreSQL extension that runs scheduled jobs directly in the database. It's perfect for serverless architectures because:

- Runs independently of your API backend
- No additional infrastructure required
- Perfect for database-centric operations
- Free and open source
- Reliable and battle-tested

### Limitations

**Cannot directly**:
- Call external HTTP APIs (Mapbox, payment processors, email services)
- Execute Go code or complex business logic
- Send push notifications or emails

**Workaround for external API calls**:
- Use PostgreSQL's `http` extension for simple HTTP requests
- Create database triggers that set flags, then have your serverless API poll for flags
- Use hybrid approach: pg_cron + cloud scheduler for complex tasks

---

## Setup pg_cron with Docker

### Option 1: Use citusdata/pg_cron Docker Image (EASIEST)

Replace `postgres:16-alpine` with a pre-built image that includes pg_cron.

**Update docker-compose.yml**:

```yaml
services:
  postgres:
    image: citusdata/pg_cron:latest  # Includes PostgreSQL + pg_cron
    container_name: delivery_app_db
    command: postgres -c shared_preload_libraries=pg_cron -c cron.database_name=delivery_app
    environment:
      POSTGRES_USER: delivery_user
      POSTGRES_PASSWORD: delivery_pass
      POSTGRES_DB: delivery_app
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/sql/schema.sql:/docker-entrypoint-initdb.d/001-schema.sql
      - ./backend/sql/pg_cron_setup.sql:/docker-entrypoint-initdb.d/002-pg_cron.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U delivery_user -d delivery_app"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Option 2: Custom Dockerfile with pg_cron (MORE CONTROL)

If you need alpine or specific PostgreSQL version:

**Create `backend/sql/Dockerfile.postgres`**:

```dockerfile
FROM postgres:16-alpine

# Install build dependencies and pg_cron
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    make \
    musl-dev \
    postgresql-dev \
    git \
    && git clone https://github.com/citusdata/pg_cron.git /tmp/pg_cron \
    && cd /tmp/pg_cron \
    && make \
    && make install \
    && apk del .build-deps \
    && rm -rf /tmp/pg_cron

# Preload pg_cron extension
RUN echo "shared_preload_libraries = 'pg_cron'" >> /usr/local/share/postgresql/postgresql.conf.sample
```

**Update docker-compose.yml**:

```yaml
services:
  postgres:
    build:
      context: ./backend/sql
      dockerfile: Dockerfile.postgres
    container_name: delivery_app_db
    command: postgres -c shared_preload_libraries=pg_cron -c cron.database_name=delivery_app
    environment:
      POSTGRES_USER: delivery_user
      POSTGRES_PASSWORD: delivery_pass
      POSTGRES_DB: delivery_app
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/sql/schema.sql:/docker-entrypoint-initdb.d/001-schema.sql
      - ./backend/sql/pg_cron_setup.sql:/docker-entrypoint-initdb.d/002-pg_cron.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U delivery_user -d delivery_app"]
      interval: 10s
      timeout: 5s
      retries: 5
```

---

## pg_cron SQL Setup

**Create `backend/sql/pg_cron_setup.sql`**:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant permissions to delivery_user
GRANT USAGE ON SCHEMA cron TO delivery_user;

-- ============================================================================
-- SCHEDULED JOB DEFINITIONS
-- ============================================================================

-- Job 1: Auto-cancel unconfirmed orders after 30 minutes
-- Runs every minute to check for orders that should be cancelled
SELECT cron.schedule(
    'auto-cancel-unconfirmed-orders',  -- Job name
    '* * * * *',                         -- Every minute
    $$
    UPDATE orders
    SET
        status = 'cancelled'::order_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = 'Auto-cancelled: vendor did not confirm within 30 minutes',
        updated_at = CURRENT_TIMESTAMP
    WHERE
        status = 'pending'::order_status
        AND placed_at IS NOT NULL
        AND placed_at < (CURRENT_TIMESTAMP - INTERVAL '30 minutes')
        AND is_active = true;
    $$
);

-- Job 2: Clean up orphaned menus (no restaurant association)
-- Runs daily at 2 AM
SELECT cron.schedule(
    'cleanup-orphaned-menus',
    '0 2 * * *',                         -- Daily at 2:00 AM
    $$
    DELETE FROM menus
    WHERE id NOT IN (
        SELECT DISTINCT menu_id FROM restaurant_menus
    )
    AND created_at < (CURRENT_TIMESTAMP - INTERVAL '30 days');
    $$
);

-- Job 3: Archive old completed orders (move to cold storage or mark inactive)
-- Runs weekly on Sunday at 3 AM
SELECT cron.schedule(
    'archive-old-orders',
    '0 3 * * 0',                         -- Weekly on Sunday at 3:00 AM
    $$
    UPDATE orders
    SET is_active = false
    WHERE
        status IN ('delivered'::order_status, 'cancelled'::order_status, 'refunded'::order_status)
        AND delivered_at < (CURRENT_TIMESTAMP - INTERVAL '90 days')
        AND is_active = true;
    $$
);

-- Job 4: Update restaurant ratings (recalculate from reviews)
-- Runs daily at 1 AM
SELECT cron.schedule(
    'update-restaurant-ratings',
    '0 1 * * *',                         -- Daily at 1:00 AM
    $$
    -- This is a placeholder - implement when review system exists
    -- UPDATE restaurants
    -- SET rating = (SELECT AVG(rating) FROM reviews WHERE restaurant_id = restaurants.id)
    -- WHERE id IN (SELECT DISTINCT restaurant_id FROM reviews WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 day');
    SELECT 1; -- No-op for now
    $$
);

-- Job 5: Clean up expired sessions or tokens
-- Runs every hour
SELECT cron.schedule(
    'cleanup-expired-sessions',
    '0 * * * *',                         -- Every hour
    $$
    -- Placeholder for when session tracking is implemented
    -- DELETE FROM user_sessions WHERE expires_at < CURRENT_TIMESTAMP;
    SELECT 1; -- No-op for now
    $$
);

-- Job 6: Generate daily order statistics
-- Runs daily at 11:59 PM
SELECT cron.schedule(
    'generate-daily-stats',
    '59 23 * * *',                       -- Daily at 11:59 PM
    $$
    -- Placeholder for analytics
    -- INSERT INTO daily_order_stats (date, total_orders, total_revenue, ...)
    -- SELECT CURRENT_DATE, COUNT(*), SUM(total_amount), ...
    -- FROM orders WHERE DATE(created_at) = CURRENT_DATE;
    SELECT 1; -- No-op for now
    $$
);
```

---

## Managing pg_cron Jobs

### View All Scheduled Jobs

```sql
-- List all cron jobs
SELECT * FROM cron.job;

-- List jobs with their schedules
SELECT
    jobid,
    jobname,
    schedule,
    active,
    database
FROM cron.job
ORDER BY jobid;
```

### View Job Execution History

```sql
-- Recent job runs with status
SELECT
    jobid,
    runid,
    job_pid,
    database,
    username,
    command,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;

-- Failed job runs
SELECT
    j.jobname,
    jrd.start_time,
    jrd.status,
    jrd.return_message
FROM cron.job_run_details jrd
JOIN cron.job j ON jrd.jobid = j.jobid
WHERE jrd.status = 'failed'
ORDER BY jrd.start_time DESC;
```

### Pause/Resume Jobs

```sql
-- Pause a job
UPDATE cron.job SET active = false WHERE jobname = 'auto-cancel-unconfirmed-orders';

-- Resume a job
UPDATE cron.job SET active = true WHERE jobname = 'auto-cancel-unconfirmed-orders';
```

### Modify Job Schedule

```sql
-- Update schedule (every 5 minutes instead of every minute)
UPDATE cron.job
SET schedule = '*/5 * * * *'
WHERE jobname = 'auto-cancel-unconfirmed-orders';
```

### Delete a Job

```sql
-- Remove a scheduled job
SELECT cron.unschedule('job-name-here');
```

### Run a Job Manually

```sql
-- Execute a job immediately (useful for testing)
SELECT cron.schedule('test-job', 'now', $$ SELECT 1; $$);
```

---

## Cron Schedule Syntax

pg_cron uses standard cron syntax:

```
 ┌───────────── minute (0 - 59)
 │ ┌───────────── hour (0 - 23)
 │ │ ┌───────────── day of month (1 - 31)
 │ │ │ ┌───────────── month (1 - 12)
 │ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
 │ │ │ │ │
 │ │ │ │ │
 * * * * *
```

**Common Examples**:

```sql
-- Every minute
'* * * * *'

-- Every 5 minutes
'*/5 * * * *'

-- Every hour at minute 0
'0 * * * *'

-- Daily at 2:30 AM
'30 2 * * *'

-- Weekly on Monday at 3 AM
'0 3 * * 1'

-- Monthly on the 1st at midnight
'0 0 1 * *'

-- Weekdays at 9 AM
'0 9 * * 1-5'
```

---

## Alternative: Cloud Provider Schedulers

When you need to call external APIs or run complex Go logic:

### AWS: EventBridge + Lambda

**Setup**:

1. Deploy your Go backend as Lambda function
2. Create EventBridge rule with cron expression
3. Target your Lambda function

**Example EventBridge Rule**:

```json
{
  "ScheduleExpression": "cron(0 2 * * ? *)",
  "Targets": [
    {
      "Arn": "arn:aws:lambda:us-east-1:123456789:function:delivery-app-scheduled-tasks",
      "Input": "{\"task\": \"auto-cancel-orders\"}"
    }
  ]
}
```

**Lambda Handler** (Go):

```go
package main

import (
    "context"
    "encoding/json"

    "github.com/aws/aws-lambda-go/lambda"
)

type ScheduledEvent struct {
    Task string `json:"task"`
}

func handleScheduledTask(ctx context.Context, event ScheduledEvent) error {
    switch event.Task {
    case "auto-cancel-orders":
        return autoCancelOrders()
    case "send-notifications":
        return sendDailyNotifications()
    default:
        return fmt.Errorf("unknown task: %s", event.Task)
    }
}

func main() {
    lambda.Start(handleScheduledTask)
}
```

### Google Cloud: Cloud Scheduler + Cloud Functions

**Setup**:

1. Deploy Go function to Cloud Functions
2. Create Cloud Scheduler job
3. Configure HTTP target with authentication

**Example gcloud command**:

```bash
gcloud scheduler jobs create http auto-cancel-orders \
    --schedule="0 */1 * * *" \
    --uri="https://us-central1-project.cloudfunctions.net/scheduled-tasks" \
    --http-method=POST \
    --message-body='{"task":"auto-cancel-orders"}' \
    --oidc-service-account-email=scheduler@project.iam.gserviceaccount.com
```

---

## Hybrid Approach: Best of Both Worlds

Use **pg_cron** for database operations and **cloud schedulers** for external API calls:

**pg_cron handles**:
- Auto-cancel orders
- Archive old data
- Update aggregations
- Clean up orphaned records

**Cloud Scheduler handles**:
- Send email/SMS notifications
- Call Mapbox API for route optimization
- Process payments/refunds
- Sync with third-party services

---

## Common Scheduled Tasks for Delivery App

### 1. Auto-Cancel Unconfirmed Orders

**Use case**: Vendor hasn't confirmed order within 30 minutes

**Implementation**: pg_cron (SQL-based)

```sql
SELECT cron.schedule(
    'auto-cancel-unconfirmed-orders',
    '* * * * *',  -- Every minute
    $$
    UPDATE orders
    SET
        status = 'cancelled'::order_status,
        cancelled_at = CURRENT_TIMESTAMP,
        cancellation_reason = 'Auto-cancelled: vendor did not confirm within 30 minutes',
        updated_at = CURRENT_TIMESTAMP
    WHERE
        status = 'pending'::order_status
        AND placed_at IS NOT NULL
        AND placed_at < (CURRENT_TIMESTAMP - (
            SELECT setting_value::INTEGER
            FROM system_settings
            WHERE setting_key = 'order_auto_cancel_minutes'
        ) * INTERVAL '1 minute')
        AND is_active = true;
    $$
);
```

### 2. Send Daily Vendor Reports

**Use case**: Email daily order summary to vendors

**Implementation**: Cloud Scheduler + Lambda (requires external email service)

**Pseudo-code**:

```go
func sendDailyVendorReports() error {
    // Query database for yesterday's orders per vendor
    // Format report
    // Send via SendGrid/SES
}
```

### 3. Update Restaurant Ratings

**Use case**: Recalculate average ratings from reviews

**Implementation**: pg_cron (SQL-based)

```sql
UPDATE restaurants
SET rating = (
    SELECT COALESCE(AVG(rating), 0.00)
    FROM reviews
    WHERE restaurant_id = restaurants.id
)
WHERE id IN (
    SELECT DISTINCT restaurant_id
    FROM reviews
    WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 day'
);
```

### 4. Clean Up Old Distance API Logs

**Use case**: Delete distance_requests older than 90 days

**Implementation**: pg_cron (SQL-based)

```sql
DELETE FROM distance_requests
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';
```

### 5. Driver Inactivity Check

**Use case**: Mark drivers as unavailable if no location update in 30 minutes

**Implementation**: pg_cron (SQL-based)

```sql
UPDATE drivers
SET is_available = false
WHERE
    is_available = true
    AND updated_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes';
```

---

## Monitoring and Alerting

### Set Up Monitoring for pg_cron

**Create monitoring view**:

```sql
CREATE VIEW cron_job_health AS
SELECT
    j.jobname,
    j.active,
    j.schedule,
    COUNT(jrd.runid) AS total_runs,
    COUNT(CASE WHEN jrd.status = 'failed' THEN 1 END) AS failed_runs,
    MAX(jrd.start_time) AS last_run_time,
    MAX(CASE WHEN jrd.status = 'failed' THEN jrd.return_message END) AS last_error
FROM cron.job j
LEFT JOIN cron.job_run_details jrd ON j.jobid = jrd.jobid
    AND jrd.start_time > CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY j.jobid, j.jobname, j.active, j.schedule
ORDER BY j.jobname;
```

**Query for health check**:

```sql
SELECT * FROM cron_job_health WHERE failed_runs > 0;
```

### Alerting Strategy

**Option 1: Database trigger on failed jobs**

```sql
CREATE TABLE cron_alerts (
    id SERIAL PRIMARY KEY,
    jobname TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to log failures
-- (Requires custom function to insert into cron_alerts on failure)
```

**Option 2: External monitoring**

Poll `cron.job_run_details` from your monitoring service:

```python
# Example Python script for monitoring
import psycopg2
import requests

conn = psycopg2.connect(DATABASE_URL)
cursor = conn.cursor()

cursor.execute("""
    SELECT jobname, return_message, start_time
    FROM cron.job_run_details
    WHERE status = 'failed'
    AND start_time > NOW() - INTERVAL '1 hour'
""")

failures = cursor.fetchall()
if failures:
    # Send alert to Slack/PagerDuty
    requests.post(SLACK_WEBHOOK, json={
        "text": f"pg_cron failures detected: {failures}"
    })
```

---

## Security Considerations

1. **Least Privilege**: Grant only necessary permissions to scheduled job user
2. **SQL Injection**: Use parameterized queries (pg_cron uses `$$` for escaping)
3. **Rate Limiting**: Don't schedule jobs too frequently (avoid every second)
4. **Timeout Protection**: Set statement_timeout in PostgreSQL config
5. **Monitoring**: Always monitor job execution history

---

## Testing Scheduled Jobs

### Test Jobs Locally

```bash
# Start PostgreSQL with pg_cron
docker-compose up -d postgres

# Connect to database
psql "postgres://delivery_user:delivery_pass@localhost:5433/delivery_app"

# Run job SQL manually
UPDATE orders
SET status = 'cancelled'::order_status
WHERE status = 'pending'::order_status
  AND placed_at < (CURRENT_TIMESTAMP - INTERVAL '30 minutes');

# Check affected rows
SELECT * FROM orders WHERE status = 'cancelled';
```

### Dry Run Jobs

Wrap jobs in transactions for testing:

```sql
BEGIN;

-- Run your scheduled job SQL here
UPDATE orders SET status = 'cancelled'::order_status
WHERE status = 'pending'::order_status
  AND placed_at < (CURRENT_TIMESTAMP - INTERVAL '30 minutes');

-- Review changes
SELECT * FROM orders WHERE status = 'cancelled';

-- Rollback to undo changes
ROLLBACK;
```

---

## Migration Path

### Current State (No Scheduled Jobs)

Your app currently has no background tasks running.

### Phase 1: Add pg_cron (Low Risk)

1. Update `docker-compose.yml` to use citusdata/pg_cron image
2. Create `backend/sql/pg_cron_setup.sql` with initial jobs
3. Test locally with Docker
4. Deploy to staging/production
5. Monitor job execution via `cron.job_run_details`

### Phase 2: Add Cloud Scheduler (If Needed)

Only add if you need:
- External API calls (email, SMS, payment processing)
- Complex business logic from your Go codebase
- Integration with third-party services

---

## Cost Analysis

### pg_cron

- **Cost**: FREE (runs on existing database)
- **Resource Impact**: Minimal (lightweight SQL queries)
- **Scaling**: Limited by database CPU/memory

### AWS EventBridge + Lambda

- **EventBridge**: $1.00 per million events
- **Lambda**: $0.20 per 1M requests + compute time
- **Example**: 10 jobs/hour = 7,200 jobs/month = $0.0072 + compute

### Google Cloud Scheduler + Functions

- **Cloud Scheduler**: 3 free jobs, $0.10/job/month after
- **Cloud Functions**: 2M free invocations/month
- **Example**: 10 jobs/hour = effectively FREE on free tier

---

## Recommendations for Your Delivery App

### Immediate Implementation (pg_cron)

1. **Auto-cancel unconfirmed orders** (every minute)
2. **Clean up orphaned menus** (daily at 2 AM)
3. **Archive old orders** (weekly on Sunday)
4. **Update driver availability** (every 5 minutes)

### Future Additions (Cloud Scheduler)

When you implement these features:

1. **Send order confirmation emails** (requires SendGrid/SES)
2. **Send daily vendor reports** (requires email service)
3. **Push notifications for drivers** (requires FCM/APNS)
4. **Sync with accounting system** (requires external API)

---

## Files to Create

1. **`backend/sql/pg_cron_setup.sql`** - Scheduled job definitions
2. **`docker-compose.yml`** - Update PostgreSQL image (or custom Dockerfile)
3. **`backend/docs/SCHEDULED_JOBS.md`** - This documentation (already created)
4. **`backend/docs/pg_cron_monitoring.sql`** - Monitoring queries

---

## Next Steps

1. Review this document
2. Decide on pg_cron vs cloud scheduler approach
3. Update `docker-compose.yml` with pg_cron support
4. Create `pg_cron_setup.sql` with initial jobs
5. Test locally with `docker-compose up`
6. Monitor job execution via `cron.job_run_details`
7. Add alerting for failed jobs

---

## Additional Resources

- [pg_cron GitHub](https://github.com/citusdata/pg_cron)
- [pg_cron Documentation](https://github.com/citusdata/pg_cron#what-is-pg_cron)
- [Crontab Guru](https://crontab.guru/) - Cron schedule expression builder
- [AWS EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html)
- [Google Cloud Scheduler](https://cloud.google.com/scheduler/docs)
