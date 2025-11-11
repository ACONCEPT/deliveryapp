# Scheduled Jobs Implementation Guide

## Overview

This document describes the implementation of scheduled jobs for the delivery app using Go CLI + Docker Cron solution.

## What Was Implemented

### 1. Backend Jobs Package (`backend/jobs/scheduled_jobs.go`)

Created four job functions that handle automated maintenance tasks:

- **CancelUnconfirmedOrders()**: Cancels orders vendors haven't confirmed within 30 minutes
- **CleanupOrphanedMenus()**: Removes menus not linked to restaurants (older than 30 days)
- **ArchiveOldOrders()**: Marks old delivered/cancelled orders as inactive (older than 90 days)
- **UpdateDriverAvailability()**: Marks inactive drivers as unavailable (no update in 30 minutes)

Each function:
- Accepts `*sqlx.DB` as parameter
- Returns `error`
- Logs the number of rows affected
- Uses efficient SQL queries with proper indexing

### 2. CLI Integration (`backend/main.go`)

Updated main.go to support CLI mode:

- Added Cobra dependency for CLI argument parsing
- Added `runJobsCLI()` function that sets up job commands
- Added `runHTTPServer()` function for existing HTTP server logic
- Main function routes to CLI or HTTP based on first argument

**CLI Commands:**
```bash
./delivery_app jobs cancel-unconfirmed-orders
./delivery_app jobs cleanup-orphaned-menus
./delivery_app jobs archive-old-orders
./delivery_app jobs update-driver-availability
./delivery_app jobs --help
```

### 3. Docker Scheduler Service (`docker-compose.yml`)

Added new `scheduler` service:

- Uses same Dockerfile as API service
- Installs dcron (Alpine cron daemon)
- Configures crontab with job schedules
- Runs cron in foreground mode
- Logs to `/var/log/cron.log`

**Cron Schedules:**
- Cancel unconfirmed orders: Every minute (`* * * * *`)
- Cleanup orphaned menus: Daily at 2 AM (`0 2 * * *`)
- Archive old orders: Weekly on Sunday at 3 AM (`0 3 * * 0`)
- Update driver availability: Every 5 minutes (`*/5 * * * *`)

### 4. Dependencies

Added Cobra library for CLI support:
```bash
go get github.com/spf13/cobra@latest
```

## Files Created/Modified

### Created:
- `/Users/josephsadaka/Repos/delivery_app/backend/jobs/scheduled_jobs.go` - Job implementations
- `/Users/josephsadaka/Repos/delivery_app/backend/jobs/README.md` - Comprehensive job documentation
- `/Users/josephsadaka/Repos/delivery_app/SCHEDULED_JOBS_IMPLEMENTATION.md` - This file

### Modified:
- `/Users/josephsadaka/Repos/delivery_app/backend/main.go` - Added CLI mode support
- `/Users/josephsadaka/Repos/delivery_app/docker-compose.yml` - Added scheduler service
- `/Users/josephsadaka/Repos/delivery_app/backend/go.mod` - Added cobra dependency
- `/Users/josephsadaka/Repos/delivery_app/backend/go.sum` - Updated checksums

## Testing Locally

### 1. Build the Backend
```bash
cd /Users/josephsadaka/Repos/delivery_app/backend
go build -o delivery_app .
```

### 2. Test Individual Jobs
```bash
# Test cancel unconfirmed orders
./delivery_app jobs cancel-unconfirmed-orders

# Test cleanup orphaned menus
./delivery_app jobs cleanup-orphaned-menus

# Test archive old orders
./delivery_app jobs archive-old-orders

# Test update driver availability
./delivery_app jobs update-driver-availability

# View all available jobs
./delivery_app jobs --help
```

Expected output for each job:
```
2025/11/05 23:00:36 [CONFIG] JWT_SECRET loaded (length: 36 chars, first 4: chan...)
2025/11/05 23:00:36 ✓ Database connection established (timezone: UTC)
2025/11/05 23:00:36 [JOB] Running <JobName>...
2025/11/05 23:00:36 [JOB] <JobName>: No <items> to <action>
2025/11/05 23:00:36 Closing database connection
Job completed successfully
```

### 3. Verify HTTP Server Still Works
```bash
# Start server normally (without "jobs" argument)
./delivery_app

# Should see:
# Starting Delivery App API Server...
# Server listening on :8080
```

### 4. Test with Docker Compose

Start all services including scheduler:
```bash
cd /Users/josephsadaka/Repos/delivery_app
docker-compose up -d --build
```

Check scheduler status:
```bash
# View scheduler logs
docker logs delivery_app_scheduler

# Follow logs in real-time
docker logs -f delivery_app_scheduler

# View cron job output
docker exec delivery_app_scheduler tail -f /var/log/cron.log

# Check crontab configuration
docker exec delivery_app_scheduler cat /etc/crontabs/root
```

Stop services:
```bash
docker-compose down
```

## Job Details

### 1. Cancel Unconfirmed Orders

**SQL Query:**
```sql
UPDATE orders
SET
    status = 'cancelled'::order_status,
    cancelled_at = CURRENT_TIMESTAMP,
    cancellation_reason = 'Order not confirmed by vendor within 30 minutes',
    updated_at = CURRENT_TIMESTAMP
WHERE
    status = 'pending'
    AND placed_at IS NOT NULL
    AND placed_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
    AND cancelled_at IS NULL
RETURNING id
```

**Purpose:** Ensure vendors respond to orders promptly, improving customer experience

**Frequency:** Every minute (critical for timely order processing)

### 2. Cleanup Orphaned Menus

**SQL Query:**
```sql
DELETE FROM menus
WHERE id IN (
    SELECT m.id
    FROM menus m
    LEFT JOIN restaurant_menus rm ON m.id = rm.menu_id
    WHERE rm.id IS NULL
      AND m.created_at < CURRENT_TIMESTAMP - INTERVAL '30 days'
      AND m.is_active = false
)
RETURNING id, name
```

**Purpose:** Remove unused menu templates to reduce database bloat

**Frequency:** Daily at 2 AM (low traffic time)

### 3. Archive Old Orders

**SQL Query:**
```sql
UPDATE orders
SET
    is_active = false,
    updated_at = CURRENT_TIMESTAMP
WHERE
    is_active = true
    AND status IN ('delivered', 'cancelled', 'refunded')
    AND (
        delivered_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
        OR cancelled_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
    )
RETURNING id
```

**Purpose:** Improve query performance by marking old orders as inactive (data is preserved)

**Frequency:** Weekly on Sunday at 3 AM

### 4. Update Driver Availability

**SQL Query:**
```sql
UPDATE drivers
SET
    is_available = false,
    updated_at = CURRENT_TIMESTAMP
WHERE
    is_available = true
    AND updated_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
RETURNING id, full_name
```

**Purpose:** Ensure driver availability status is accurate for order assignment

**Frequency:** Every 5 minutes

## Architecture Benefits

### 1. Single Binary Deployment
- Same binary runs HTTP server and jobs
- No separate job runner executable needed
- Shared configuration and database connection logic

### 2. Easy Testing
- Jobs can be run manually for testing
- No need to wait for cron schedule
- Same environment as production

### 3. Observable
- All jobs log their actions
- Centralized logging via cron.log
- Easy to monitor job execution

### 4. Maintainable
- Jobs are pure Go functions
- Easy to add new jobs
- Simple to modify schedules

### 5. Production Ready
- Docker containerized
- Auto-restart on failure
- Health checks and dependencies

## Monitoring and Operations

### Check Job Execution
```bash
# View recent job runs
docker exec delivery_app_scheduler tail -n 100 /var/log/cron.log

# Search for specific job
docker exec delivery_app_scheduler grep "cancel-unconfirmed-orders" /var/log/cron.log

# Check for errors
docker exec delivery_app_scheduler grep -i "error\|failed" /var/log/cron.log
```

### Verify Cron is Running
```bash
# Check if cron process is running
docker exec delivery_app_scheduler ps | grep crond

# View cron daemon logs
docker logs delivery_app_scheduler | grep -i "cron"
```

### Restart Scheduler
```bash
# Restart just the scheduler service
docker-compose restart scheduler

# Rebuild and restart (after code changes)
docker-compose up -d --build scheduler
```

### Adjust Job Schedules
Edit `docker-compose.yml` and modify the crontab section:
```yaml
# Example: Change cleanup to run at 3 AM instead of 2 AM
0 3 * * * /app/delivery_app jobs cleanup-orphaned-menus >> /var/log/cron.log 2>&1
```

Then restart:
```bash
docker-compose up -d --build scheduler
```

## Adding New Jobs

See `/Users/josephsadaka/Repos/delivery_app/backend/jobs/README.md` for detailed instructions on adding new jobs.

## Troubleshooting

### Job Not Running

**Symptom:** Job doesn't appear in logs

**Solutions:**
1. Check scheduler container is running:
   ```bash
   docker ps | grep scheduler
   ```

2. Verify crontab syntax:
   ```bash
   docker exec delivery_app_scheduler cat /etc/crontabs/root
   ```

3. Check cron daemon is running:
   ```bash
   docker exec delivery_app_scheduler ps | grep crond
   ```

### Job Failing

**Symptom:** Job runs but returns errors

**Solutions:**
1. Test job manually:
   ```bash
   docker exec delivery_app_scheduler /app/delivery_app jobs <job-name>
   ```

2. Check database connectivity:
   ```bash
   docker exec delivery_app_scheduler ping postgres
   ```

3. Verify environment variables:
   ```bash
   docker exec delivery_app_scheduler env | grep DATABASE
   ```

4. Check application logs:
   ```bash
   docker logs delivery_app_scheduler
   ```

### Performance Issues

**Symptom:** Jobs taking too long or causing database load

**Solutions:**
1. Check query performance:
   ```sql
   EXPLAIN ANALYZE <job_query>
   ```

2. Add indexes if needed
3. Reduce job frequency
4. Batch large operations

## Next Steps

### Recommended Enhancements

1. **Add Job Metrics**
   - Track job execution time
   - Count items processed
   - Alert on failures

2. **Add Job History Table**
   - Log all job executions
   - Track success/failure rates
   - Store execution metadata

3. **Add Job Locking**
   - Prevent concurrent job execution
   - Use advisory locks or database flags
   - Handle job timeouts

4. **Add Alerting**
   - Notify on job failures
   - Alert on zero items processed (may indicate issue)
   - Email/Slack notifications

5. **Add Job Dashboard**
   - Web UI to view job status
   - Manual job trigger buttons
   - Historical execution data

### Production Deployment Checklist

- [ ] Test all jobs manually in staging
- [ ] Verify cron schedules are appropriate
- [ ] Set up log rotation for cron.log
- [ ] Configure monitoring and alerts
- [ ] Document job schedules for operations team
- [ ] Set up backup strategy for job history
- [ ] Test job failure scenarios
- [ ] Verify resource limits (CPU, memory)

## Resources

- Cobra CLI Documentation: https://github.com/spf13/cobra
- Docker Compose Reference: https://docs.docker.com/compose/
- Alpine Linux Cron: https://wiki.alpinelinux.org/wiki/Alpine_Linux:FAQ#How_do_I_configure_a_cron_job
- PostgreSQL Intervals: https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-INTERVAL-INPUT

## Support

For questions or issues:
1. Check backend/jobs/README.md for detailed documentation
2. Review docker logs: `docker logs delivery_app_scheduler`
3. Test jobs manually: `./delivery_app jobs <job-name>`
4. Check database schema: `/Users/josephsadaka/Repos/delivery_app/backend/sql/schema.sql`
