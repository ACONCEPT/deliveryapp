# Scheduled Jobs

This directory contains scheduled maintenance and cleanup jobs for the delivery app.

## Available Jobs

### 1. Cancel Unconfirmed Orders
**Command:** `cancel-unconfirmed-orders`
**Schedule:** Every minute
**Purpose:** Automatically cancel orders that vendors haven't confirmed within 30 minutes
**Details:**
- Finds orders in 'pending' status
- Checks if placed_at timestamp is older than 30 minutes
- Updates status to 'cancelled' with appropriate cancellation reason
- Logs the number of orders cancelled and their IDs

### 2. Cleanup Orphaned Menus
**Command:** `cleanup-orphaned-menus`
**Schedule:** Daily at 2 AM
**Purpose:** Remove menus not linked to any restaurants to reduce database bloat
**Details:**
- Finds menus with no restaurant_menus entries
- Only deletes inactive menus (is_active = false)
- Only deletes menus older than 30 days
- Logs the number of menus deleted with their names

### 3. Archive Old Orders
**Command:** `archive-old-orders`
**Schedule:** Weekly on Sunday at 3 AM
**Purpose:** Mark old delivered/cancelled orders as inactive to improve query performance
**Details:**
- Finds orders in 'delivered', 'cancelled', or 'refunded' status
- Only archives orders older than 90 days (from delivered_at or cancelled_at)
- Sets is_active = false (data is preserved, not deleted)
- Logs the number of orders archived with sample IDs

### 4. Update Driver Availability
**Command:** `update-driver-availability`
**Schedule:** Every 5 minutes
**Purpose:** Ensure driver availability status is accurate for order assignment
**Details:**
- Finds drivers with is_available = true
- Checks if updated_at is older than 30 minutes
- Sets is_available = false for inactive drivers
- Logs the number of drivers updated with their names

## Running Jobs Manually

You can run any job manually for testing or one-off execution:

```bash
# From the backend directory
./delivery_app jobs cancel-unconfirmed-orders
./delivery_app jobs cleanup-orphaned-menus
./delivery_app jobs archive-old-orders
./delivery_app jobs update-driver-availability

# View all available jobs
./delivery_app jobs --help

# View help for a specific job
./delivery_app jobs cancel-unconfirmed-orders --help
```

## Docker Scheduler Service

The jobs are automatically scheduled in production via the `scheduler` service in docker-compose.yml:

```yaml
scheduler:
  build:
    context: ./backend
    dockerfile: Dockerfile
  container_name: delivery_app_scheduler
  environment:
    DATABASE_URL: postgres://...
  depends_on:
    postgres:
      condition: service_healthy
  restart: unless-stopped
```

The scheduler service:
1. Uses the same Docker image as the API server
2. Installs dcron (Alpine cron daemon)
3. Configures crontab with all scheduled jobs
4. Runs cron in foreground mode
5. Logs all job output to `/var/log/cron.log`

## Cron Schedule

```cron
# Cancel unconfirmed orders - every minute
* * * * * /app/delivery_app jobs cancel-unconfirmed-orders

# Cleanup orphaned menus - daily at 2 AM
0 2 * * * /app/delivery_app jobs cleanup-orphaned-menus

# Archive old orders - weekly on Sunday at 3 AM
0 3 * * 0 /app/delivery_app jobs archive-old-orders

# Update driver availability - every 5 minutes
*/5 * * * * /app/delivery_app jobs update-driver-availability
```

## Monitoring

### View Scheduler Logs
```bash
# View scheduler container logs
docker logs delivery_app_scheduler

# Follow logs in real-time
docker logs -f delivery_app_scheduler

# View cron job output
docker exec delivery_app_scheduler tail -f /var/log/cron.log
```

### Check Scheduler Status
```bash
# Check if scheduler is running
docker ps | grep scheduler

# Restart scheduler
docker restart delivery_app_scheduler

# View crontab configuration
docker exec delivery_app_scheduler cat /etc/crontabs/root
```

## Adding New Jobs

To add a new scheduled job:

1. **Add job function** to `backend/jobs/scheduled_jobs.go`:
```go
func MyNewJob(db *sqlx.DB) error {
    log.Println("[JOB] Running MyNewJob...")

    // Your job logic here

    return nil
}
```

2. **Add CLI command** in `backend/main.go` (runJobsCLI function):
```go
var myJobCmd = &cobra.Command{
    Use:   "my-new-job",
    Short: "Description of my new job",
    Run: func(cmd *cobra.Command, args []string) {
        if err := jobs.MyNewJob(app.DB); err != nil {
            log.Fatalf("Job failed: %v", err)
        }
        fmt.Println("Job completed successfully")
    },
}
jobsCmd.AddCommand(myJobCmd)
```

3. **Add cron schedule** in `docker-compose.yml` (scheduler service):
```cron
# My new job - every hour
0 * * * * /app/delivery_app jobs my-new-job >> /var/log/cron.log 2>&1
```

4. **Test manually**:
```bash
go build -o delivery_app .
./delivery_app jobs my-new-job
```

5. **Deploy**:
```bash
docker-compose up -d --build scheduler
docker logs -f delivery_app_scheduler
```

## Best Practices

1. **Logging**: Always log job start, completion, and affected rows
2. **Error Handling**: Return errors, don't panic
3. **Idempotency**: Jobs should be safe to run multiple times
4. **Performance**: Use indexes and efficient queries
5. **Testing**: Test jobs manually before deploying
6. **Monitoring**: Check logs regularly to ensure jobs are running
7. **Timing**: Schedule resource-intensive jobs during off-peak hours

## Troubleshooting

### Job not running
- Check scheduler container is running: `docker ps | grep scheduler`
- Check crontab syntax: `docker exec delivery_app_scheduler cat /etc/crontabs/root`
- Check cron logs: `docker exec delivery_app_scheduler tail -f /var/log/cron.log`

### Job failing
- Check database connectivity: `docker exec delivery_app_scheduler ping postgres`
- Check environment variables: `docker exec delivery_app_scheduler env | grep DATABASE`
- Run job manually: `docker exec delivery_app_scheduler /app/delivery_app jobs <job-name>`

### Performance issues
- Check query plans: Run EXPLAIN ANALYZE on job queries
- Add indexes if needed
- Adjust job frequency
- Consider batching large operations

## Architecture

The scheduled jobs implementation follows these design principles:

1. **Separation of Concerns**: Jobs are in a separate package (`backend/jobs/`)
2. **CLI Integration**: Jobs are exposed as CLI commands using Cobra
3. **Reusable**: Same binary runs HTTP server and scheduled jobs
4. **Containerized**: Jobs run in a dedicated Docker container
5. **Observable**: All jobs log their actions and results
6. **Maintainable**: Easy to add, modify, or remove jobs
