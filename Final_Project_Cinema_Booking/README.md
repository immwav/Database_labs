# Online Cinema Ticket Booking System
## Final Database Project

### Project Overview

This project implements a comprehensive database system for an **Online Cinema Ticket Booking System**. The system allows users to browse movies, view showtimes, book tickets, and manage their reservations through a PostgreSQL database backend.

### Information

- **Course**: Database
- **Institution**: AUCA
- **Semester**: Fall 2025
- **Project Type**: Final Project

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Database Schema](#database-schema)
3. [Cinema Booking System-2025-12-14-144654.png](#er-diagram)
4. [Installation & Setup](#installation--setup)
5. [Database Schema Implementation](#database-schema-implementation)
6. [Sample Data](#sample-data)
7. [SQL Queries](#sql-queries)
8. [Transactions](#transactions)
9. [Indexing Strategy](#indexing-strategy)
10. [Backup & Restore](#backup--restore)
11. [Features](#features)
12. [Database Normalization](#database-normalization)
13. [Future Enhancements](#future-enhancements)

---

## Project Structure

```
Final_Project_Cinema_Booking/
│
├── Cinema Booking System-2025-12-14-144654.png                 # Entity Relationship Diagram documentation
├── 01_database_schema.sql        # Database schema DDL (tables, constraints, triggers)
├── 02_sample_data.sql            # Sample data insertion scripts
├── 03_basic_queries.sql          # Basic SQL queries
├── 04_advanced_queries.sql       # Advanced SQL queries (subqueries, CTEs, window functions)
├── 05_transactions.sql           # Transaction demonstrations
├── 06_indexing.sql               # Indexing strategies and examples
├── 07_backup_restore.md          # Backup and restore strategy documentation
├── backup_script.sh              # Automated backup script
├── restore_script.sh             # Database restore script
└── README.md                     # This file
```

---

## Database Schema

### Entity Descriptions

#### 1. **users**
Stores user account information
- `user_id` (PK): Unique identifier
- `name`: User's full name
- `email`: Email address (unique)
- `phone`: Phone number
- `password_hash`: Hashed password
- `created_at`: Account creation timestamp

#### 2. **movies**
Stores movie information
- `movie_id` (PK): Unique identifier
- `title`: Movie title
- `genre`: Movie genre
- `duration`: Duration in minutes
- `rating`: MPAA rating (G, PG, PG-13, R, NC-17, NR)
- `description`: Movie description
- `release_date`: Release date

#### 3. **halls**
Stores cinema hall information
- `hall_id` (PK): Unique identifier
- `name`: Hall name
- `capacity`: Total seat capacity
- `screen_type`: Screen technology (2D, 3D, IMAX, 4DX, etc.)

#### 4. **seats**
Stores seat information for each hall
- `seat_id` (PK): Unique identifier
- `hall_id` (FK): References halls
- `row_number`: Row identifier (A, B, C, etc.)
- `seat_number`: Seat number within row
- `seat_type`: Type of seat (regular, VIP, premium)
- Unique constraint: (hall_id, row_number, seat_number)

#### 5. **showtimes**
Stores movie showtime information
- `showtime_id` (PK): Unique identifier
- `movie_id` (FK): References movies
- `hall_id` (FK): References halls
- `start_time`: Show start time
- `end_time`: Show end time
- `date`: Show date
- `price`: Base ticket price
- Unique constraint: (hall_id, date, start_time) - prevents overlapping showtimes

#### 6. **bookings**
Stores booking information
- `booking_id` (PK): Unique identifier
- `user_id` (FK): References users
- `showtime_id` (FK): References showtimes
- `total_amount`: Total booking amount
- `status`: Booking status (pending, confirmed, cancelled)
- `created_at`: Booking creation timestamp
- `updated_at`: Last update timestamp (auto-updated)

#### 7. **tickets**
Stores individual ticket information
- `ticket_id` (PK): Unique identifier
- `booking_id` (FK): References bookings
- `seat_id` (FK): References seats
- `price`: Ticket price
- `status`: Ticket status (active, cancelled)
- `created_at`: Ticket creation timestamp

### Relationships

- Users → Bookings (One-to-Many)
- Bookings → Tickets (One-to-Many)
- Showtimes → Bookings (One-to-Many)
- Movies → Showtimes (One-to-Many)
- Halls → Showtimes (One-to-Many)
- Halls → Seats (One-to-Many)
- Seats → Tickets (One-to-Many)

---


## Installation & Setup

### Prerequisites

- PostgreSQL 12 or higher
- psql command-line tool
- Basic knowledge of SQL and database administration

### Step 1: Create Database

```bash
# Connect to PostgreSQL as superuser
psql -U postgres

# Create database
CREATE DATABASE cinema_booking;

# Exit psql
\q
```

### Step 2: Run Schema Script

```bash
# Run the schema creation script
psql -U postgres -d cinema_booking -f 01_database_schema.sql
```

### Step 3: Insert Sample Data

```bash
# Insert sample data
psql -U postgres -d cinema_booking -f 02_sample_data.sql
```

### Step 4: Verify Installation

```bash
# Connect to database
psql -U postgres -d cinema_booking

# Check tables
\dt

# Check data
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM movies;
SELECT COUNT(*) FROM bookings;
```

---

## Database Schema Implementation

The complete database schema is implemented in `01_database_schema.sql` and includes:

- **Tables**: All 7 entity tables with proper constraints
- **Primary Keys**: All tables have primary keys
- **Foreign Keys**: All relationships are enforced with foreign key constraints
- **Constraints**: Check constraints for data validation
- **Indexes**: Performance indexes on frequently queried columns
- **Triggers**: 
  - Auto-update `updated_at` timestamp
  - Prevent double booking of seats
- **Views**:
  - `available_seats_view`: Shows seat availability per showtime
  - `booking_details_view`: Complete booking information

### Key Features

1. **Data Integrity**: Foreign keys ensure referential integrity
2. **Validation**: Check constraints validate data ranges and values
3. **Prevents Double Booking**: Trigger prevents booking the same seat twice for the same showtime
4. **Automatic Timestamps**: Triggers maintain updated_at timestamps

---

## Sample Data

The `02_sample_data.sql` script inserts:

- **5 users** with sample account information
- **8 movies** across various genres
- **5 cinema halls** with different capacities and screen types
- **750+ seats** across all halls (different seat types)
- **25+ showtimes** for various movies and dates
- **5 bookings** with associated tickets

You can modify this data to add more test cases or use it as-is for testing.

---

## SQL Queries

### Basic Queries (`03_basic_queries.sql`)

Includes:
- SELECT statements with WHERE clauses
- JOIN operations (INNER, LEFT)
- Aggregate functions (COUNT, SUM, AVG, MIN, MAX)
- ORDER BY and LIMIT/OFFSET
- LIKE pattern matching
- DISTINCT queries
- CASE statements
- Date and time functions

**Examples:**
- List all movies by genre
- Find showtimes for a specific date
- Calculate total revenue per user
- Find upcoming showtimes

### Advanced Queries (`04_advanced_queries.sql`)

Includes:
- Subqueries and nested queries
- Window functions (RANK, DENSE_RANK, LAG, LEAD)
- Common Table Expressions (CTEs)
- Recursive CTEs
- Complex multi-table joins
- Set operations (UNION, EXCEPT, INTERSECT)
- Conditional aggregation
- EXISTS and NOT EXISTS clauses
- Date range queries

**Examples:**
- Find most popular movies by ticket sales
- Calculate running totals
- Find available seats for a showtime
- Daily revenue reports
- Hall utilization statistics

---

## Transactions

The `05_transactions.sql` file demonstrates:

1. **Complete Booking Process**: Atomic transaction for creating bookings and tickets
2. **Booking Cancellation**: Rollback demonstration
3. **Seat Availability Checks**: Isolation level examples
4. **Batch Operations**: Multiple ticket purchases in one transaction
5. **Savepoints**: Partial rollback capabilities
6. **Data Integrity Checks**: Consistency validation
7. **Concurrent Booking Simulation**: Isolation level demonstrations

### ACID Properties Demonstrated

- **Atomicity**: All-or-nothing booking creation
- **Consistency**: Constraints maintained during transactions
- **Isolation**: Concurrent transaction handling
- **Durability**: Committed changes persist

---

## Indexing Strategy

The `06_indexing.sql` file includes:

### Index Types

1. **Primary Key Indexes**: Automatic unique indexes
2. **Foreign Key Indexes**: For join performance
3. **Composite Indexes**: Multi-column indexes for common query patterns
4. **Partial Indexes**: Indexes with WHERE clauses
5. **Covering Indexes**: INCLUDE columns for index-only scans
6. **Full Text Search**: GIN indexes for text search
7. **Expression Indexes**: For computed values

### Performance Optimization

- Index usage monitoring
- Query performance analysis (EXPLAIN ANALYZE)
- Index maintenance (REINDEX, VACUUM ANALYZE)
- Unused index identification

### Index Strategy Documentation

Detailed documentation of indexing decisions and their rationale is included in the script comments.

---

## Backup & Restore

### Documentation

See [07_backup_restore.md](07_backup_restore.md) for complete backup and restore strategy.

### Backup Methods

1. **pg_dump**: Logical backup (recommended for regular backups)
2. **pg_basebackup**: Physical backup
3. **WAL Archiving**: Continuous archiving for point-in-time recovery

### Automated Scripts

- **backup_script.sh**: Automated backup script with options for full/schema/data backups
- **restore_script.sh**: Database restore script with verification

### Usage

```bash
# Make scripts executable
chmod +x backup_script.sh restore_script.sh

# Full backup
./backup_script.sh full

# Schema-only backup
./backup_script.sh schema

# Restore database
./restore_script.sh /backup/cinema_booking/cinema_booking_full_20240115.dump --drop-existing
```

### Backup Schedule

- **Daily**: Full database backup at 2:00 AM
- **Weekly**: Schema backup on Sundays
- **Continuous**: WAL archiving for point-in-time recovery

---

## Features

### Core Features

1.  User account management
2.  Movie catalog management
3.  Cinema hall and seat management
4.  Showtime scheduling
5.  Ticket booking system
6.  Seat availability checking
7.  Booking status management
8.  Data integrity enforcement


## Database Normalization

The database is normalized to **Third Normal Form (3NF)**:

### First Normal Form (1NF)
-  All attributes have atomic values
-  No repeating groups

### Second Normal Form (2NF)
-  All tables are in 1NF
-  All non-key attributes fully depend on primary key

### Third Normal Form (3NF)
- All tables are in 2NF
- No transitive dependencies

### Normalization Benefits

- Eliminates data redundancy
- Ensures data integrity
- Simplifies maintenance
- Improves query performance

---

## SQL Query Examples

### Example 1: Find Available Seats for a Showtime

```sql
SELECT 
    se.seat_id,
    se.row_number,
    se.seat_number,
    se.seat_type,
    CASE 
        WHEN t.ticket_id IS NULL OR t.status = 'cancelled' THEN 'Available'
        ELSE 'Booked'
    END AS availability
FROM showtimes s
JOIN halls h ON s.hall_id = h.hall_id
JOIN seats se ON h.hall_id = se.hall_id
LEFT JOIN tickets t ON se.seat_id = t.seat_id
LEFT JOIN bookings b ON t.booking_id = b.booking_id 
    AND b.showtime_id = s.showtime_id 
    AND b.status != 'cancelled'
WHERE s.showtime_id = 1
    AND (t.ticket_id IS NULL OR t.status = 'cancelled' OR b.status = 'cancelled')
ORDER BY se.row_number, se.seat_number;
```

### Example 2: Calculate Revenue by Movie

```sql
SELECT 
    m.movie_id,
    m.title,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(t.ticket_id) AS tickets_sold,
    SUM(b.total_amount) AS total_revenue
FROM movies m
JOIN showtimes s ON m.movie_id = s.movie_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status = 'confirmed'
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY m.movie_id, m.title
ORDER BY total_revenue DESC;
```

### Example 3: User Booking History

```sql
SELECT 
    b.booking_id,
    m.title AS movie_title,
    h.name AS hall_name,
    s.date AS show_date,
    s.start_time,
    COUNT(t.ticket_id) AS ticket_count,
    b.total_amount,
    b.status,
    b.created_at
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id
JOIN halls h ON s.hall_id = h.hall_id
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
WHERE u.user_id = 1
GROUP BY b.booking_id, m.title, h.name, s.date, s.start_time, 
         b.total_amount, b.status, b.created_at
ORDER BY b.created_at DESC;
```

---

## Testing

### Manual Testing Steps

1. **Schema Validation**: Verify all tables are created correctly
   ```sql
   \dt
   SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
   ```

2. **Data Integrity**: Check foreign key constraints
   ```sql
   SELECT * FROM bookings WHERE user_id NOT IN (SELECT user_id FROM users);
   ```

3. **Trigger Testing**: Test double booking prevention
   ```sql
   -- This should fail (seat already booked)
   INSERT INTO tickets (booking_id, seat_id, price, status)
   VALUES (1, 1, 450.00, 'active');
   ```

4. **Transaction Testing**: Verify atomic operations
   - Create a booking with tickets
   - Verify all-or-nothing behavior

---

## Project Deliverables Summary

 **ER Diagram**: Complete entity relationship diagram with documentation  
 **Database Schema**: Normalized PostgreSQL schema implementation  
 **SQL Queries**: Comprehensive basic and advanced queries  
 **Transactions**: ACID property demonstrations  
 **Indexing**: Performance optimization strategy  
 **Backup & Restore**: Complete backup and recovery strategy  
 **Documentation**: Detailed README and inline documentation  

---

## Author Information

- **Student Name**: Rysbekov Almazbek
- **Course**: Database 
- **Institution**: AUCA
- **Year**: 2025


## Repository Information

This project is available on GitHub/GitLab:
- Repository URL: https://github.com/immwav/Database_labs


---

**Last Updated**: January 2025

