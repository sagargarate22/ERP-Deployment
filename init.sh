#!/bin/bash

# 2. Start Database and wait
docker compose up -d db
echo "Waiting for database to be ready..."
until docker exec backend_db pg_isready -U ${DB_USER}; do
  sleep 2
done

# 3. Handle S3 Restore (First-time safe)
mkdir -p ./backups
echo "Checking S3 for backups..."
rclone copy contabo-s3:erp-prod-bucket/backups ./backups --max-depth 1 2>/dev/null

# Find the newest .sql file
LATEST_BACKUP=$(ls -t ./backups/*.sql 2>/dev/null | head -1)

if [ -f "$LATEST_BACKUP" ]; then
    echo "Restoring from $LATEST_BACKUP..."
    cat "$LATEST_BACKUP" | docker exec -i backend_db psql -U ${DB_USER} -d ${DB_NAME}
else
    echo "No backup files found on S3. Starting with fresh DB."
fi

# 4. Start the full application
docker compose up -d

# 5. Request real SSL (Nginx must be running for this)
echo "Requesting real SSL..."
docker compose run --rm certbot certonly --webroot -w /var/www/certbot \
    -d ${DOMAIN} --email ${EMAIL} --agree-tos --no-eff-email --force-renewal

# 6. Reload Nginx
docker compose exec gateway nginx -s reload

# 7. SETUP CRON JOBS (The safe way that preserves existing jobs)
echo "Setting up Cron jobs..."

# Clear existing crontab to avoid duplicates on re-runs
crontab -r 2>/dev/null

crontab -r 2>/dev/null

(
echo "0 4 * * 1 cd /opt/erp && docker compose run --rm certbot renew && docker compose exec -T gateway nginx -s reload"
echo "5 4 * * * rclone sync /opt/erp/backups contabo-s3:erp-prod-bucket/backups"
) | crontab -