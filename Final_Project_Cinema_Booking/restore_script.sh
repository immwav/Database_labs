#!/bin/bash
# Restore script for Cinema Booking Database
# Usage: ./restore_script.sh <backup_file.dump> [--drop-existing]

BACKUP_FILE=$1
DROP_EXISTING=$2
DB_NAME="cinema_booking"
DB_USER="postgres"
DB_HOST="localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if backup file is provided
if [ -z "$BACKUP_FILE" ]; then
    error "No backup file specified"
    echo "Usage: $0 <backup_file.dump> [--drop-existing]"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Verify backup file integrity
log "Verifying backup file..."
pg_restore -l "$BACKUP_FILE" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    error "Backup file appears to be corrupted or invalid"
    exit 1
fi

log "Backup file verified successfully"

# Drop existing database if requested
if [ "$DROP_EXISTING" == "--drop-existing" ]; then
    warning "Dropping existing database: $DB_NAME"
    
    # Terminate existing connections
    psql -h $DB_HOST -U $DB_USER -d postgres -c "
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
    " > /dev/null 2>&1
    
    # Drop database
    psql -h $DB_HOST -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
    
    if [ $? -ne 0 ]; then
        error "Failed to drop existing database"
        exit 1
    fi
    
    log "Database dropped successfully"
fi

# Check if database exists, create if not
DB_EXISTS=$(psql -h $DB_HOST -U $DB_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

if [ "$DB_EXISTS" != "1" ]; then
    log "Creating database: $DB_NAME"
    psql -h $DB_HOST -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"
    
    if [ $? -ne 0 ]; then
        error "Failed to create database"
        exit 1
    fi
    
    log "Database created successfully"
else
    log "Database already exists: $DB_NAME"
fi

# Perform restore
log "Starting database restore from: $BACKUP_FILE"
log "This may take several minutes depending on backup size..."

pg_restore -h $DB_HOST -U $DB_USER -d $DB_NAME -v "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    log "Database restore completed successfully!"
    
    # Verify restore by counting records
    log "Verifying restored data..."
    RECORD_COUNTS=$(psql -h $DB_HOST -U $DB_USER -d $DB_NAME -tAc "
        SELECT 
            'Users: ' || COUNT(*) FROM users
        UNION ALL
        SELECT 'Movies: ' || COUNT(*) FROM movies
        UNION ALL
        SELECT 'Bookings: ' || COUNT(*) FROM bookings
        UNION ALL
        SELECT 'Tickets: ' || COUNT(*) FROM tickets;
    ")
    
    log "Record counts after restore:"
    echo "$RECORD_COUNTS" | while read line; do
        log "  $line"
    done
    
    log "Restore verification completed"
else
    error "Database restore failed!"
    exit 1
fi

log "Restore process completed successfully"

