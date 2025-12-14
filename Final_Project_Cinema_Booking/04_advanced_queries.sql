-- =====================================================
-- Advanced SQL Queries
-- Online Cinema Ticket Booking System
-- =====================================================

\c cinema_booking;

-- =====================================================
-- 1. Subqueries and Nested Queries
-- =====================================================

-- 1.1. Find movies that have showtimes today (using subquery)
SELECT * FROM movies
WHERE movie_id IN (
    SELECT DISTINCT movie_id 
    FROM showtimes 
    WHERE date = CURRENT_DATE
);

-- 1.2. Find users who have spent more than average
SELECT 
    u.user_id,
    u.name,
    SUM(b.total_amount) AS total_spent
FROM users u
JOIN bookings b ON u.user_id = b.user_id
WHERE b.status = 'confirmed'
GROUP BY u.user_id, u.name
HAVING SUM(b.total_amount) > (
    SELECT AVG(total_amount)
    FROM bookings
    WHERE status = 'confirmed'
);

-- 1.3. Find halls that have never been used for showtimes
SELECT * FROM halls
WHERE hall_id NOT IN (
    SELECT DISTINCT hall_id FROM showtimes
);

-- 1.4. Find showtimes with maximum price
SELECT * FROM showtimes
WHERE price = (SELECT MAX(price) FROM showtimes);

-- 1.5. Find users with more bookings than any other user
SELECT 
    u.user_id,
    u.name,
    COUNT(b.booking_id) AS booking_count
FROM users u
JOIN bookings b ON u.user_id = b.user_id
GROUP BY u.user_id, u.name
HAVING COUNT(b.booking_id) >= ALL (
    SELECT COUNT(booking_id)
    FROM bookings
    GROUP BY user_id
);

-- =====================================================
-- 2. Window Functions
-- =====================================================

-- 2.1. Rank movies by average showtime price
SELECT 
    m.movie_id,
    m.title,
    AVG(s.price) AS avg_price,
    RANK() OVER (ORDER BY AVG(s.price) DESC) AS price_rank
FROM movies m
JOIN showtimes s ON m.movie_id = s.movie_id
GROUP BY m.movie_id, m.title;

-- 2.2. Calculate running total of bookings per user
SELECT 
    booking_id,
    user_id,
    total_amount,
    SUM(total_amount) OVER (
        PARTITION BY user_id 
        ORDER BY created_at
    ) AS running_total
FROM bookings
WHERE status = 'confirmed';

-- 2.3. Show previous and next showtime for each showtime
SELECT 
    showtime_id,
    movie_id,
    date,
    start_time,
    LAG(start_time) OVER (PARTITION BY hall_id, date ORDER BY start_time) AS previous_showtime,
    LEAD(start_time) OVER (PARTITION BY hall_id, date ORDER BY start_time) AS next_showtime
FROM showtimes
ORDER BY hall_id, date, start_time;

-- 2.4. Calculate percentage of seats booked per showtime
SELECT 
    s.showtime_id,
    m.title,
    h.name AS hall_name,
    h.capacity,
    COUNT(DISTINCT t.seat_id) AS booked_seats,
    ROUND(
        100.0 * COUNT(DISTINCT t.seat_id) / h.capacity, 
        2
    ) AS booking_percentage
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
JOIN halls h ON s.hall_id = h.hall_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status != 'cancelled'
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY s.showtime_id, m.title, h.name, h.capacity;

-- 2.5. Find the most popular movie (by number of tickets sold)
SELECT 
    m.movie_id,
    m.title,
    COUNT(t.ticket_id) AS tickets_sold,
    DENSE_RANK() OVER (ORDER BY COUNT(t.ticket_id) DESC) AS popularity_rank
FROM movies m
JOIN showtimes s ON m.movie_id = s.movie_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status != 'cancelled'
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY m.movie_id, m.title;

-- =====================================================
-- 3. Common Table Expressions (CTEs)
-- =====================================================

-- 3.1. Find booking statistics using CTE
WITH booking_stats AS (
    SELECT 
        user_id,
        COUNT(*) AS total_bookings,
        SUM(total_amount) AS total_revenue
    FROM bookings
    WHERE status = 'confirmed'
    GROUP BY user_id
)
SELECT 
    u.name,
    u.email,
    COALESCE(bs.total_bookings, 0) AS bookings,
    COALESCE(bs.total_revenue, 0) AS revenue
FROM users u
LEFT JOIN booking_stats bs ON u.user_id = bs.user_id
ORDER BY revenue DESC NULLS LAST;

-- 3.2. Recursive CTE: Find all seats in a hall
WITH RECURSIVE seat_generator AS (
    SELECT 1 AS seat_number
    UNION ALL
    SELECT seat_number + 1
    FROM seat_generator
    WHERE seat_number < 20
)
SELECT * FROM seat_generator;

-- 3.3. Find showtime availability using CTE
WITH booked_seats AS (
    SELECT 
        s.showtime_id,
        COUNT(DISTINCT t.seat_id) AS booked_count
    FROM showtimes s
    LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status != 'cancelled'
    LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
    GROUP BY s.showtime_id
),
hall_capacity AS (
    SELECT 
        s.showtime_id,
        h.capacity
    FROM showtimes s
    JOIN halls h ON s.hall_id = h.hall_id
)
SELECT 
    s.showtime_id,
    m.title,
    hc.capacity,
    COALESCE(bs.booked_count, 0) AS booked,
    hc.capacity - COALESCE(bs.booked_count, 0) AS available
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
JOIN hall_capacity hc ON s.showtime_id = hc.showtime_id
LEFT JOIN booked_seats bs ON s.showtime_id = bs.showtime_id;

-- =====================================================
-- 4. Complex Joins with Multiple Tables
-- =====================================================

-- 4.1. Complete booking information with all details
SELECT 
    b.booking_id,
    u.name AS customer_name,
    u.email AS customer_email,
    m.title AS movie_title,
    m.genre,
    h.name AS hall_name,
    h.screen_type,
    s.date AS show_date,
    s.start_time,
    s.end_time,
    STRING_AGG(
        se.row_number || se.seat_number || ' (' || se.seat_type || ')',
        ', ' ORDER BY se.row_number, se.seat_number
    ) AS seats,
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
LEFT JOIN seats se ON t.seat_id = se.seat_id
GROUP BY b.booking_id, u.name, u.email, m.title, m.genre, h.name, h.screen_type,
         s.date, s.start_time, s.end_time, b.total_amount, b.status, b.created_at;

-- 4.2. Find available seats for a specific showtime
SELECT 
    se.seat_id,
    se.row_number,
    se.seat_number,
    se.seat_type,
    CASE 
        WHEN t.ticket_id IS NULL OR t.status = 'cancelled' OR b.status = 'cancelled' 
        THEN 'Available'
        ELSE 'Booked'
    END AS availability_status
FROM showtimes s
JOIN halls h ON s.hall_id = h.hall_id
JOIN seats se ON h.hall_id = se.hall_id
LEFT JOIN tickets t ON se.seat_id = t.seat_id
LEFT JOIN bookings b ON t.booking_id = b.booking_id AND b.showtime_id = s.showtime_id
WHERE s.showtime_id = 1
ORDER BY se.row_number, se.seat_number;

-- =====================================================
-- 5. Set Operations (UNION, INTERSECT, EXCEPT)
-- =====================================================

-- 5.1. Find all users who have bookings OR have registered recently
SELECT user_id, name, 'Has Booking' AS category
FROM users
WHERE user_id IN (SELECT DISTINCT user_id FROM bookings)
UNION
SELECT user_id, name, 'Recent Registration' AS category
FROM users
WHERE created_at > CURRENT_DATE - INTERVAL '30 days';

-- 5.2. Find movies shown in Hall A but not in Hall B
SELECT DISTINCT movie_id, title
FROM movies
WHERE movie_id IN (
    SELECT movie_id FROM showtimes WHERE hall_id = 1
)
EXCEPT
SELECT DISTINCT movie_id, title
FROM movies
WHERE movie_id IN (
    SELECT movie_id FROM showtimes WHERE hall_id = 2
);

-- =====================================================
-- 6. Conditional Aggregation
-- =====================================================

-- 6.1. Revenue breakdown by booking status
SELECT 
    status,
    COUNT(*) AS booking_count,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_amount,
    MIN(total_amount) AS min_amount,
    MAX(total_amount) AS max_amount
FROM bookings
GROUP BY status;

-- 6.2. Movie popularity by ticket sales and revenue
SELECT 
    m.movie_id,
    m.title,
    COUNT(DISTINCT b.booking_id) AS total_bookings,
    COUNT(t.ticket_id) AS total_tickets_sold,
    SUM(b.total_amount) AS total_revenue,
    AVG(b.total_amount) AS avg_booking_amount
FROM movies m
LEFT JOIN showtimes s ON m.movie_id = s.movie_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status = 'confirmed'
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY m.movie_id, m.title
ORDER BY total_revenue DESC NULLS LAST;

-- 6.3. Hall utilization statistics
SELECT 
    h.hall_id,
    h.name,
    h.capacity,
    COUNT(DISTINCT s.showtime_id) AS total_showtimes,
    COUNT(DISTINCT t.seat_id) AS total_seats_booked,
    COUNT(DISTINCT t.ticket_id) AS total_tickets_sold,
    ROUND(
        100.0 * COUNT(DISTINCT t.seat_id) / NULLIF(COUNT(DISTINCT s.showtime_id) * h.capacity, 0),
        2
    ) AS utilization_percentage
FROM halls h
LEFT JOIN showtimes s ON h.hall_id = s.hall_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id AND b.status != 'cancelled'
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY h.hall_id, h.name, h.capacity;

-- =====================================================
-- 7. Date Range Queries
-- =====================================================

-- 7.1. Showtimes in the next week grouped by day
SELECT 
    s.date,
    COUNT(*) AS showtime_count,
    COUNT(DISTINCT s.movie_id) AS unique_movies,
    MIN(s.start_time) AS earliest_showtime,
    MAX(s.end_time) AS latest_showtime
FROM showtimes s
WHERE s.date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
GROUP BY s.date
ORDER BY s.date;

-- 7.2. Daily revenue report for the last 7 days
SELECT 
    DATE(b.created_at) AS booking_date,
    COUNT(DISTINCT b.booking_id) AS bookings_count,
    COUNT(t.ticket_id) AS tickets_sold,
    SUM(b.total_amount) AS daily_revenue
FROM bookings b
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
WHERE b.created_at >= CURRENT_DATE - INTERVAL '7 days'
  AND b.status = 'confirmed'
GROUP BY DATE(b.created_at)
ORDER BY booking_date DESC;

-- =====================================================
-- 8. EXISTS and NOT EXISTS
-- =====================================================

-- 8.1. Find movies that have upcoming showtimes
SELECT m.*
FROM movies m
WHERE EXISTS (
    SELECT 1 
    FROM showtimes s 
    WHERE s.movie_id = m.movie_id 
    AND s.date >= CURRENT_DATE
);

-- 8.2. Find users who have never made a booking
SELECT u.*
FROM users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM bookings b 
    WHERE b.user_id = u.user_id
);

-- 8.3. Find seats that are never booked
SELECT se.*
FROM seats se
WHERE NOT EXISTS (
    SELECT 1 
    FROM tickets t
    JOIN bookings b ON t.booking_id = b.booking_id
    WHERE t.seat_id = se.seat_id
    AND t.status = 'active'
    AND b.status != 'cancelled'
);

