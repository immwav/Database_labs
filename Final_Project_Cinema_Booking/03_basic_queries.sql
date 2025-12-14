-- =====================================================
-- Basic SQL Queries
-- Online Cinema Ticket Booking System
-- =====================================================

\c cinema_booking;

-- =====================================================
-- 1. SELECT Queries
-- =====================================================

-- 1.1. List all movies
SELECT * FROM movies;

-- 1.2. List all users
SELECT user_id, name, email, phone FROM users;

-- 1.3. List all showtimes for today
SELECT * FROM showtimes WHERE date = CURRENT_DATE;

-- 1.4. List all halls with their capacity
SELECT hall_id, name, capacity, screen_type FROM halls;

-- 1.5. List all confirmed bookings
SELECT * FROM bookings WHERE status = 'confirmed';

-- =====================================================
-- 2. WHERE Clauses
-- =====================================================

-- 2.1. Find movies by genre
SELECT title, genre, duration, rating 
FROM movies 
WHERE genre = 'Sci-Fi';

-- 2.2. Find movies released after 2010
SELECT title, release_date, genre 
FROM movies 
WHERE release_date > '2010-01-01'
ORDER BY release_date DESC;

-- 2.3. Find showtimes with price less than 400
SELECT s.showtime_id, m.title, s.date, s.start_time, s.price
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
WHERE s.price < 400.00;

-- 2.4. Find VIP halls
SELECT * FROM halls WHERE screen_type LIKE '%VIP%' OR name LIKE '%VIP%';

-- 2.5. Find bookings for a specific user
SELECT b.booking_id, b.total_amount, b.status, b.created_at
FROM bookings b
WHERE b.user_id = 1;

-- =====================================================
-- 3. JOIN Queries
-- =====================================================

-- 3.1. Show movie details with showtimes
SELECT 
    m.title,
    m.genre,
    m.duration,
    s.date,
    s.start_time,
    s.end_time,
    s.price,
    h.name AS hall_name
FROM movies m
JOIN showtimes s ON m.movie_id = s.movie_id
JOIN halls h ON s.hall_id = h.hall_id
ORDER BY s.date, s.start_time;

-- 3.2. Show booking details with user and movie information
SELECT 
    u.name AS user_name,
    u.email,
    m.title AS movie_title,
    s.date AS show_date,
    s.start_time,
    b.total_amount,
    b.status
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id;

-- 3.3. Show ticket details with seat information
SELECT 
    t.ticket_id,
    se.row_number,
    se.seat_number,
    se.seat_type,
    t.price,
    t.status
FROM tickets t
JOIN seats se ON t.seat_id = se.seat_id
WHERE t.booking_id = 1;

-- 3.4. Show complete booking information
SELECT 
    b.booking_id,
    u.name AS user_name,
    m.title AS movie_title,
    h.name AS hall_name,
    s.date,
    s.start_time,
    COUNT(t.ticket_id) AS number_of_tickets,
    b.total_amount,
    b.status
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id
JOIN halls h ON s.hall_id = h.hall_id
LEFT JOIN tickets t ON b.booking_id = t.booking_id
GROUP BY b.booking_id, u.name, m.title, h.name, s.date, s.start_time, b.total_amount, b.status;

-- =====================================================
-- 4. Aggregate Functions
-- =====================================================

-- 4.1. Count total number of movies
SELECT COUNT(*) AS total_movies FROM movies;

-- 4.2. Count bookings per status
SELECT status, COUNT(*) AS booking_count
FROM bookings
GROUP BY status;

-- 4.3. Calculate average ticket price per showtime
SELECT 
    s.showtime_id,
    m.title,
    AVG(t.price) AS average_ticket_price,
    COUNT(t.ticket_id) AS tickets_sold
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
LEFT JOIN bookings b ON s.showtime_id = b.showtime_id
LEFT JOIN tickets t ON b.booking_id = t.booking_id
GROUP BY s.showtime_id, m.title;

-- 4.4. Calculate total revenue per user
SELECT 
    u.user_id,
    u.name,
    SUM(b.total_amount) AS total_spent,
    COUNT(b.booking_id) AS total_bookings
FROM users u
LEFT JOIN bookings b ON u.user_id = b.user_id
WHERE b.status = 'confirmed'
GROUP BY u.user_id, u.name;

-- 4.5. Find hall with most seats
SELECT name, capacity FROM halls ORDER BY capacity DESC LIMIT 1;

-- =====================================================
-- 5. ORDER BY Queries
-- =====================================================

-- 5.1. List movies by release date (newest first)
SELECT title, genre, release_date
FROM movies
ORDER BY release_date DESC NULLS LAST;

-- 5.2. List showtimes by date and time
SELECT m.title, s.date, s.start_time, s.price
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
ORDER BY s.date, s.start_time;

-- 5.3. List bookings by creation date (most recent first)
SELECT booking_id, user_id, total_amount, status, created_at
FROM bookings
ORDER BY created_at DESC;

-- =====================================================
-- 6. LIMIT and OFFSET
-- =====================================================

-- 6.1. Get top 5 most recent bookings
SELECT * FROM bookings
ORDER BY created_at DESC
LIMIT 5;

-- 6.2. Pagination: Get movies (page 2, 3 items per page)
SELECT * FROM movies
ORDER BY movie_id
LIMIT 3 OFFSET 3;

-- =====================================================
-- 7. LIKE and Pattern Matching
-- =====================================================

-- 7.1. Search movies by title
SELECT * FROM movies
WHERE title LIKE '%Matrix%';

-- 7.2. Find users by email domain
SELECT * FROM users
WHERE email LIKE '%@email.com%';

-- 7.3. Find halls with "Premium" in name
SELECT * FROM halls
WHERE name LIKE '%Premium%';

-- =====================================================
-- 8. DISTINCT Queries
-- =====================================================

-- 8.1. Get all unique genres
SELECT DISTINCT genre FROM movies ORDER BY genre;

-- 8.2. Get all unique screen types
SELECT DISTINCT screen_type FROM halls;

-- 8.3. Get all dates with showtimes
SELECT DISTINCT date FROM showtimes ORDER BY date;

-- =====================================================
-- 9. CASE Statements
-- =====================================================

-- 9.1. Categorize movies by duration
SELECT 
    title,
    duration,
    CASE 
        WHEN duration < 120 THEN 'Short'
        WHEN duration < 150 THEN 'Medium'
        ELSE 'Long'
    END AS duration_category
FROM movies;

-- 9.2. Categorize bookings by amount
SELECT 
    booking_id,
    total_amount,
    CASE 
        WHEN total_amount < 500 THEN 'Low'
        WHEN total_amount < 1000 THEN 'Medium'
        ELSE 'High'
    END AS amount_category
FROM bookings;

-- =====================================================
-- 10. Date and Time Functions
-- =====================================================

-- 10.1. Show upcoming showtimes (next 7 days)
SELECT 
    m.title,
    s.date,
    s.start_time,
    s.price
FROM showtimes s
JOIN movies m ON s.movie_id = m.movie_id
WHERE s.date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY s.date, s.start_time;

-- 10.2. Find bookings made today
SELECT * FROM bookings
WHERE DATE(created_at) = CURRENT_DATE;

-- 10.3. Calculate age of movies in days
SELECT 
    title,
    release_date,
    CURRENT_DATE - release_date AS days_since_release
FROM movies
WHERE release_date IS NOT NULL;

