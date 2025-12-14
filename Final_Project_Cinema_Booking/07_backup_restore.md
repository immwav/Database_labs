# Backup and Restore Strategy
## Online Cinema Ticket Booking System

## Overview

This document outlines the comprehensive backup and restore strategy for the Cinema Ticket Booking System database. A proper backup strategy is crucial for data protection, disaster recovery, and business continuity.

## Backup Types

### 1. Full Backup
A complete backup of the entire database including all data, schema, indexes, and constraints.

### 2. Incremental Backup
Backups that only include changes since the last backup. PostgreSQL uses WAL (Write-Ahead Logging) for this purpose.

### 3. Continuous Archiving
PostgreSQL's WAL archiving provides point-in-time recovery (PITR) capabilities.

## Backup Methods

### Method 1: pg_dump (Logical Backup)

#### Full Database Backup
```bash
# Backup entire database
pg_dump -h localhost -U postgres -d cinema_booking -F c -f cinema_booking_backup_$(date +%Y%m%d_%H%M%S).dump

# Backup with verbose output
pg_dump -h localhost -U postgres -d cinema_booking -F c -v -f cinema_booking_backup.dump

# Backup with compression
pg_dump -h localhost -U postgres -d cinema_booking -F c -Z 9 -f cinema_booking_backup.dump
```

#### Schema Only Backup
```bash
pg_dump -h localhost -U postgres -d cinema_booking -F c --schema-only -f cinema_booking_schema.dump
```

#### Data Only Backup
```bash
pg_dump -h localhost -U postgres -d cinema_booking -F c --data-only -f cinema_booking_data.dump
```

#### Specific Tables Backup
```bash
pg_dump -h localhost -U postgres -d cinema_booking -F c -t bookings -t tickets -f bookings_tickets_backup.dump
```

### Method 2: pg_dumpall (All Databases)
```bash
pg_dumpall -h localhost -U postgres -f all_databases_backup_$(date +%Y%m%d).sql
```

### Method 3: File System Backup (Physical Backup)

#### Base Backup
```bash
# Stop PostgreSQL (or use pg_start_backup for hot backup)
pg_basebackup -h localhost -U postgres -D /backup/postgresql/$(date +%Y%m%d) -Ft -z -P -W
```

#### Hot Backup (Without Stopping Database)
```bash
# Connect to database
psql -h localhost -U postgres -d cinema_booking

# Mark start of backup
SELECT pg_start_backup('backup_label', false, false);

# Copy data directory (in another terminal)
sudo cp -R /var/lib/postgresql/data/* /backup/postgresql/backup_$(date +%Y%m%d)/

# Mark end of backup
SELECT pg_stop_backup();
```

### Method 4: Continuous Archiving (WAL Archiving)

#### Enable WAL Archiving in postgresql.conf
```
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backup/wal_archive/%f'
```

## Restore Methods

### Restore from pg_dump

#### Restore Full Database
```bash
# Drop existing database (CAUTION: This deletes all data!)
psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS cinema_booking;"

# Create new database
psql -h localhost -U postgres -c "CREATE DATABASE cinema_booking;"

# Restore from backup
pg_restore -h localhost -U postgres -d cinema_booking -v cinema_booking_backup.dump
```

#### Restore Schema Only
```bash
pg_restore -h localhost -U postgres -d cinema_booking --schema-only -v cinema_booking_schema.dump
```

#### Restore Data Only
```bash
pg_restore -h localhost -U postgres -d cinema_booking --data-only -v cinema_booking_data.dump
```

#### Restore Specific Tables
```bash
pg_restore -h localhost -U postgres -d cinema_booking -t bookings -t tickets -v bookings_tickets_backup.dump
```

### Restore from pg_dumpall
```bash
psql -h localhost -U postgres -f all_databases_backup.sql
```

### Point-in-Time Recovery (PITR)

#### 1. Restore Base Backup
```bash
# Stop PostgreSQL
sudo systemctl stop postgresql

# Remove old data
sudo rm -rf /var/lib/postgresql/data/*

# Restore base backup
sudo tar -xzf /backup/postgresql/base_backup.tar.gz -C /var/lib/postgresql/data/

# Create recovery.conf or recovery.signal
echo "restore_command = 'cp /backup/wal_archive/%f %p'" | sudo tee -a /var/lib/postgresql/data/recovery.conf
echo "recovery_target_time = '2024-01-15 14:30:00'" | sudo tee -a /var/lib/postgresql/data/recovery.conf

# Start PostgreSQL
sudo systemctl start postgresql
```

## Automated Backup Scripts

### Daily Backup Script

```bash
#!/bin/bash
# daily_backup.sh

BACKUP_DIR="/backup/cinema_booking"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Perform backup
pg_dump -h localhost -U postgres -d cinema_booking \
    -F c -Z 9 \
    -f $BACKUP_DIR/cinema_booking_$DATE.dump

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: cinema_booking_$DATE.dump"
    
    # Remove old backups (older than retention period)
    find $BACKUP_DIR -name "cinema_booking_*.dump" -mtime +$RETENTION_DAYS -delete
    
    echo "Old backups removed (older than $RETENTION_DAYS days)"
else
    echo "Backup failed!" | mail -s "Cinema Booking DB Backup Failed" admin@example.com
    exit 1
fi
```

### Weekly Full Backup Script

```bash
#!/bin/bash
# weekly_full_backup.sh

BACKUP_DIR="/backup/cinema_booking/weekly"
DATE=$(date +%Y%m%d)
RETENTION_WEEKS=12

mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -h localhost -U postgres -d cinema_booking \
    -F c -Z 9 \
    -f $BACKUP_DIR/cinema_booking_full_$DATE.dump

# Schema backup
pg_dump -h localhost -U postgres -d cinema_booking \
    -F c --schema-only \
    -f $BACKUP_DIR/cinema_booking_schema_$DATE.dump

# Cleanup old weekly backups
find $BACKUP_DIR -name "*.dump" -mtime +$((RETENTION_WEEKS * 7)) -delete
```

## Backup Schedule Recommendations

### Production Environment

1. **Full Database Backup**: Daily at 2:00 AM (low traffic time)
2. **Incremental/WAL Archiving**: Continuous
3. **Schema Backup**: Weekly (Sundays)
4. **Transaction Log Backup**: Every 15 minutes
5. **Off-site Backup**: Weekly (Fridays)

### Development/Testing Environment

1. **Full Database Backup**: Daily before major changes
2. **Schema Backup**: Before schema migrations
3. **Data Backup**: As needed

## Backup Verification

### Verify Backup Integrity

```bash
# List contents of backup file
pg_restore -l cinema_booking_backup.dump

# Test restore to verify backup is valid (without actually restoring)
pg_restore --schema-only -d cinema_booking_test cinema_booking_backup.dump
```

### Automated Backup Verification Script

```bash
#!/bin/bash
# verify_backup.sh

BACKUP_FILE=$1
TEST_DB="cinema_booking_test"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.dump>"
    exit 1
fi

# Create test database
psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS $TEST_DB;"
psql -h localhost -U postgres -c "CREATE DATABASE $TEST_DB;"

# Attempt restore
pg_restore -h localhost -U postgres -d $TEST_DB -v $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup verification: SUCCESS"
    
    # Verify data integrity
    RECORD_COUNT=$(psql -h localhost -U postgres -d $TEST_DB -t -c "SELECT COUNT(*) FROM bookings;")
    echo "Records in bookings table: $RECORD_COUNT"
    
    # Cleanup
    psql -h localhost -U postgres -c "DROP DATABASE $TEST_DB;"
else
    echo "Backup verification: FAILED"
    exit 1
fi
```

## Disaster Recovery Plan

### Scenario 1: Complete Database Loss

1. Stop PostgreSQL service
2. Restore from most recent full backup
3. Apply WAL archives up to desired recovery point
4. Verify data integrity
5. Restart PostgreSQL service
6. Test application connectivity

### Scenario 2: Accidental Data Deletion

1. Identify time of deletion
2. Restore to point-in-time before deletion using PITR
3. Export affected tables
4. Restore current database
5. Import recovered tables selectively

### Scenario 3: Table Corruption

1. Stop application access to affected table
2. Restore specific table from backup
3. Verify table integrity
4. Resume application access

## Backup Storage Strategy

### Local Storage
- Fast access for quick restores
- Keep last 7 days of backups
- Store on separate disk/partition

### Remote Storage
- Off-site backup copies
- Cloud storage (AWS S3, Google Cloud Storage, Azure Blob)
- Encrypted backups for security

### Backup Encryption

```bash
# Encrypt backup using GPG
pg_dump -h localhost -U postgres -d cinema_booking -F c \
    | gpg --encrypt --recipient admin@example.com \
    > cinema_booking_backup_$(date +%Y%m%d).dump.gpg

# Decrypt and restore
gpg --decrypt cinema_booking_backup.dump.gpg \
    | pg_restore -h localhost -U postgres -d cinema_booking
```

## Monitoring and Alerts

### Backup Monitoring Script

```bash
#!/bin/bash
# check_backup_status.sh

BACKUP_DIR="/backup/cinema_booking"
LAST_BACKUP=$(find $BACKUP_DIR -name "*.dump" -type f -mtime -1 | head -1)

if [ -z "$LAST_BACKUP" ]; then
    echo "ALERT: No backup found in last 24 hours!" | \
        mail -s "Backup Alert: Cinema Booking DB" admin@example.com
    exit 1
else
    BACKUP_SIZE=$(du -h "$LAST_BACKUP" | cut -f1)
    BACKUP_TIME=$(stat -c %y "$LAST_BACKUP")
    echo "Last backup: $LAST_BACKUP"
    echo "Size: $BACKUP_SIZE"
    echo "Time: $BACKUP_TIME"
fi
```

## Best Practices

1. **Test Restores Regularly**: Verify backups by testing restore procedures monthly
2. **Monitor Backup Size**: Ensure sufficient storage space
3. **Document Procedures**: Keep detailed documentation of backup/restore processes
4. **Automate Everything**: Use cron jobs or scheduling tools
5. **Keep Multiple Copies**: Follow 3-2-1 rule (3 copies, 2 different media, 1 off-site)
6. **Verify Backups**: Always verify backup integrity after creation
7. **Secure Backups**: Encrypt sensitive data in backups
8. **Monitor WAL Archive**: Ensure WAL archiving is working correctly
9. **Regular Maintenance**: Vacuum and analyze before backups
10. **Document Recovery Time**: Know your RTO (Recovery Time Objective) and RPO (Recovery Point Objective)

## Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

- **RTO (Recovery Time Objective)**: Maximum acceptable downtime = 4 hours
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss = 15 minutes

## Backup Retention Policy

- **Daily Backups**: 30 days
- **Weekly Backups**: 12 weeks (3 months)
- **Monthly Backups**: 12 months (1 year)
- **Yearly Backups**: 7 years (for compliance)

## Conclusion

A comprehensive backup and restore strategy is essential for data protection and business continuity. Regular testing, monitoring, and updates to the backup strategy ensure that the Cinema Booking System can recover from any data loss scenario efficiently and effectively.

