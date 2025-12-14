#!/bin/bash
# Backup script for Cinema Booking Database
# Usage: ./backup_script.sh [full|schema|data]

BACKUP_TYPE=${1:-full}
BACKUP_DIR="/backup/cinema_booking"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="cinema_booking"
DB_USER="postgres"
DB_HOST="localhost"
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to perform full backup
full_backup() {
    log "Starting full database backup..."
    BACKUP_FILE="$BACKUP_DIR/cinema_booking_full_$DATE.dump"
    
    pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME \
        -F c -Z 9 -v \
        -f $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "Full backup completed successfully: $BACKUP_FILE"
        log "Backup size: $BACKUP_SIZE"
        echo "$BACKUP_FILE" > "$BACKUP_DIR/last_backup.txt"
        return 0
    else
        error "Full backup failed!"
        return 1
    fi
}

# Function to perform schema-only backup
schema_backup() {
    log "Starting schema-only backup..."
    BACKUP_FILE="$BACKUP_DIR/cinema_booking_schema_$DATE.dump"
    
    pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME \
        -F c --schema-only -v \
        -f $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "Schema backup completed successfully: $BACKUP_FILE"
        log "Backup size: $BACKUP_SIZE"
        return 0
    else
        error "Schema backup failed!"
        return 1
    fi
}

# Function to perform data-only backup
data_backup() {
    log "Starting data-only backup..."
    BACKUP_FILE="$BACKUP_DIR/cinema_booking_data_$DATE.dump"
    
    pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME \
        -F c --data-only -v \
        -f $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "Data backup completed successfully: $BACKUP_FILE"
        log "Backup size: $BACKUP_SIZE"
        return 0
    else
        error "Data backup failed!"
        return 1
    fi
}

# Function to clean old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    DELETED=$(find $BACKUP_DIR -name "*.dump" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
    
    if [ $DELETED -gt 0 ]; then
        log "Deleted $DELETED old backup file(s)"
    else
        log "No old backups to delete"
    fi
}

# Function to verify backup
verify_backup() {
    BACKUP_FILE=$1
    if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE=$(cat "$BACKUP_DIR/last_backup.txt" 2>/dev/null)
    fi
    
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        warning "No backup file specified or file not found"
        return 1
    fi
    
    log "Verifying backup: $BACKUP_FILE"
    
    # List backup contents (basic verification)
    pg_restore -l "$BACKUP_FILE" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log "Backup verification: SUCCESS"
        return 0
    else
        error "Backup verification: FAILED - Backup file may be corrupted"
        return 1
    fi
}

# Main execution
case $BACKUP_TYPE in
    full)
        full_backup
        if [ $? -eq 0 ]; then
            verify_backup
            cleanup_old_backups
        fi
        ;;
    schema)
        schema_backup
        ;;
    data)
        data_backup
        ;;
    *)
        error "Invalid backup type: $BACKUP_TYPE"
        echo "Usage: $0 [full|schema|data]"
        exit 1
        ;;
esac

exit $?

