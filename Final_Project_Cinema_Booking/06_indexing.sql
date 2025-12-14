-- =====================================================
-- Indexing Strategy and Demonstrations
-- Online Cinema Ticket Booking System
-- =====================================================

\c cinema_booking;

-- =====================================================
-- 1. View Existing Indexes
-- =====================================================

-- List all indexes in the database
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Get index size and usage statistics
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- =====================================================
-- 2. Analyze Query Performance Before Indexing
-- =====================================================

-- Enable query timing
\timing on

-- Example query that might be slow without proper indexing
EXPLAIN ANALYZE
SELECT 
    u.name,
    m.title,
    s.date,
    b.total_amount
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id
WHERE b.status = 'confirmed'
    AND s.date >= CURRENT_DATE
    AND u.email = 'john.doe@email.com';

-- =====================================================
-- 3. Additional Indexes for Performance Optimization
-- =====================================================

-- 3.1. Composite index for common filtering combinations
CREATE INDEX IF NOT EXISTS idx_bookings_user_status_date 
ON bookings(user_id, status, created_at);

-- 3.2. Partial index for active bookings only
CREATE INDEX IF NOT EXISTS idx_bookings_active_status 
ON bookings(booking_id, showtime_id, total_amount)
WHERE status = 'confirmed';

-- 3.3. Index on date range queries for showtimes
CREATE INDEX IF NOT EXISTS idx_showtimes_date_range 
ON showtimes(date, start_time) 
WHERE date >= CURRENT_DATE;

-- 3.4. Index for ticket availability checks
CREATE INDEX IF NOT EXISTS idx_tickets_showtime_seat_status 
ON tickets(seat_id, status) 
INCLUDE (booking_id);

-- 3.5. Full text search index for movie titles (using GIN)
-- First, create a text search column
ALTER TABLE movies ADD COLUMN IF NOT EXISTS title_tsvector tsvector;
UPDATE movies SET title_tsvector = to_tsvector('english', title);
CREATE INDEX IF NOT EXISTS idx_movies_title_fulltext ON movies USING GIN(title_tsvector);

-- Trigger to auto-update tsvector
CREATE OR REPLACE FUNCTION movies_title_tsvector_trigger()
RETURNS TRIGGER AS $$
BEGIN
    NEW.title_tsvector := to_tsvector('english', NEW.title);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER movies_title_tsvector_update
    BEFORE INSERT OR UPDATE OF title ON movies
    FOR EACH ROW
    EXECUTE FUNCTION movies_title_tsvector_trigger();

-- 3.6. Expression index for date calculations
CREATE INDEX IF NOT EXISTS idx_showtimes_upcoming 
ON showtimes((date::text || ' ' || start_time::text)::timestamp)
WHERE date >= CURRENT_DATE;

-- 3.7. Covering index (INCLUDE columns for index-only scans)
CREATE INDEX IF NOT EXISTS idx_showtimes_movie_hall_cover
ON showtimes(movie_id, hall_id)
INCLUDE (start_time, end_time, date, price);

-- =====================================================
-- 4. Index Maintenance and Statistics
-- =====================================================

-- Update table statistics for better query planning
ANALYZE users;
ANALYZE movies;
ANALYZE halls;
ANALYZE seats;
ANALYZE showtimes;
ANALYZE bookings;
ANALYZE tickets;

-- Vacuum analyze to update statistics and reclaim space
VACUUM ANALYZE;

-- Get table and index sizes
SELECT
    pg_size_pretty(pg_total_relation_size('users')) AS users_size,
    pg_size_pretty(pg_total_relation_size('movies')) AS movies_size,
    pg_size_pretty(pg_total_relation_size('bookings')) AS bookings_size,
    pg_size_pretty(pg_total_relation_size('tickets')) AS tickets_size;

-- =====================================================
-- 5. Query Performance Comparison
-- =====================================================

-- 5.1. Test index usage with EXPLAIN
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM users WHERE email = 'john.doe@email.com';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT * FROM showtimes 
WHERE date = CURRENT_DATE 
ORDER BY start_time;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT b.*, u.name, m.title
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id
WHERE b.status = 'confirmed'
    AND s.date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days';

-- =====================================================
-- 6. Index for Full Text Search
-- =====================================================

-- Search movies by title using full text search
SELECT 
    movie_id,
    title,
    genre,
    ts_rank(title_tsvector, query) AS rank
FROM movies, to_tsquery('english', 'Matrix | Inception') query
WHERE title_tsvector @@ query
ORDER BY rank DESC;

-- =====================================================
-- 7. Index Monitoring Queries
-- =====================================================

-- Find unused indexes (may need more data/usage to be accurate)
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used,
    pg_relation_size(indexrelid) AS index_size_bytes
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelid NOT IN (
        SELECT conindid FROM pg_constraint
    )
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find duplicate indexes
SELECT
    pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS size,
    (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
    (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
FROM (
    SELECT
        indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'||
        indkey::text ||E'\n'|| COALESCE(indexprs::text,'')||E'\n' ||
        COALESCE(indpred::text,'')) AS KEY
    FROM pg_index
) sub
GROUP BY KEY HAVING COUNT(*) > 1
ORDER BY SUM(pg_relation_size(idx)) DESC;

-- =====================================================
-- 8. Index Strategy Documentation
-- =====================================================

/*
INDEXING STRATEGY DOCUMENTATION:

1. PRIMARY KEY INDEXES (Automatic)
   - All tables have primary keys which automatically create unique indexes
   - These provide fast lookups by primary key

2. FOREIGN KEY INDEXES
   - Created on all foreign key columns for join performance
   - Examples: user_id in bookings, showtime_id in bookings, etc.

3. FREQUENTLY QUERIED COLUMNS
   - email in users (unique lookup)
   - status in bookings and tickets (filtering)
   - date in showtimes (range queries)
   - genre in movies (filtering)

4. COMPOSITE INDEXES
   - (date, start_time) in showtimes for chronological queries
   - (user_id, status, created_at) in bookings for user history
   - (hall_id, date, start_time) for availability checks

5. PARTIAL INDEXES
   - Indexes with WHERE clauses for filtered queries
   - Reduces index size and improves performance
   - Example: active bookings only

6. COVERING INDEXES (INCLUDE)
   - Store additional columns in index leaf nodes
   - Enables index-only scans
   - Example: showtimes with included price and times

7. FULL TEXT SEARCH
   - GIN index on tsvector column for movie title search
   - Enables fast text search queries

8. EXPRESSION INDEXES
   - For computed values or expressions
   - Useful for date/time calculations

INDEX MAINTENANCE:
- Run ANALYZE regularly to update statistics
- Monitor index usage with pg_stat_user_indexes
- Remove unused indexes to save space
- Rebuild indexes if they become bloated (REINDEX)

QUERY OPTIMIZATION:
- Use EXPLAIN ANALYZE to verify index usage
- Ensure queries use indexed columns in WHERE clauses
- Avoid functions on indexed columns in WHERE clauses
- Use appropriate JOIN types (INNER, LEFT, etc.)
*/

-- =====================================================
-- 9. Rebuilding Indexes (if needed)
-- =====================================================

-- Rebuild a specific index
-- REINDEX INDEX idx_bookings_user_status_date;

-- Rebuild all indexes for a table
-- REINDEX TABLE bookings;

-- Rebuild all indexes in the database (use with caution)
-- REINDEX DATABASE cinema_booking;

-- =====================================================
-- 10. Index Size Comparison Report
-- =====================================================

SELECT
    'Index Sizes Report' AS report_type,
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) AS total_index_size,
    COUNT(*) AS total_indexes
FROM pg_stat_user_indexes;

SELECT
    tablename,
    COUNT(*) AS index_count,
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) AS total_index_size
FROM pg_stat_user_indexes
GROUP BY tablename
ORDER BY SUM(pg_relation_size(indexrelid)) DESC;

