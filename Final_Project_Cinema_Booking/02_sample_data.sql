-- =====================================================
-- Sample Data Insertion Script
-- Online Cinema Ticket Booking System
-- =====================================================

-- Connect to database
\c cinema_booking;

-- =====================================================
-- Insert Users
-- =====================================================
INSERT INTO users (name, email, phone, password_hash) VALUES
('John Doe', 'john.doe@email.com', '+996555123456', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
('Jane Smith', 'jane.smith@email.com', '+996555234567', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
('Alice Johnson', 'alice.j@email.com', '+996555345678', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
('Bob Williams', 'bob.williams@email.com', '+996555456789', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'),
('Emma Davis', 'emma.davis@email.com', '+996555567890', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

-- =====================================================
-- Insert Movies
-- =====================================================
INSERT INTO movies (title, genre, duration, rating, description, release_date) VALUES
('The Matrix', 'Sci-Fi', 136, 'R', 'A computer hacker learns about the true nature of reality', '1999-03-31'),
('Inception', 'Sci-Fi', 148, 'PG-13', 'A thief who steals corporate secrets through dream-sharing technology', '2010-07-16'),
('The Dark Knight', 'Action', 152, 'PG-13', 'Batman faces the Joker in Gotham City', '2008-07-18'),
('Interstellar', 'Sci-Fi', 169, 'PG-13', 'A team of explorers travel through a wormhole in space', '2014-11-07'),
('Pulp Fiction', 'Crime', 154, 'R', 'The lives of two mob hitmen, a boxer, and others intertwine', '1994-10-14'),
('The Shawshank Redemption', 'Drama', 142, 'R', 'Two imprisoned men bond over a number of years', '1994-09-23'),
('Forrest Gump', 'Drama', 142, 'PG-13', 'The presidencies of Kennedy and Johnson unfold through the perspective of an Alabama man', '1994-07-06'),
('The Avengers', 'Action', 143, 'PG-13', 'Earth mightiest heroes must come together', '2012-05-04');

-- =====================================================
-- Insert Halls
-- =====================================================
INSERT INTO halls (name, capacity, screen_type) VALUES
('Hall A - Premium', 150, 'IMAX 3D'),
('Hall B - Standard', 200, '2D'),
('Hall C - VIP', 100, '4DX'),
('Hall D - Standard', 180, '2D'),
('Hall E - Premium', 120, '3D');

-- =====================================================
-- Insert Seats for Hall A (150 seats: 10 rows × 15 seats)
-- =====================================================
INSERT INTO seats (hall_id, row_number, seat_number, seat_type)
SELECT 1, 
       CHR(65 + (seat_num / 15)), -- A, B, C, etc.
       (seat_num % 15) + 1,
       CASE 
           WHEN seat_num < 30 THEN 'VIP'  -- First 2 rows VIP
           WHEN seat_num < 60 THEN 'premium'  -- Next 2 rows premium
           ELSE 'regular'
       END
FROM generate_series(0, 149) AS seat_num;

-- Insert Seats for Hall B (200 seats: 10 rows × 20 seats)
INSERT INTO seats (hall_id, row_number, seat_number, seat_type)
SELECT 2, 
       CHR(65 + (seat_num / 20)),
       (seat_num % 20) + 1,
       CASE 
           WHEN seat_num < 40 THEN 'premium'
           ELSE 'regular'
       END
FROM generate_series(0, 199) AS seat_num;

-- Insert Seats for Hall C (100 seats: 10 rows × 10 seats - all VIP)
INSERT INTO seats (hall_id, row_number, seat_number, seat_type)
SELECT 3, 
       CHR(65 + (seat_num / 10)),
       (seat_num % 10) + 1,
       'VIP'
FROM generate_series(0, 99) AS seat_num;

-- Insert Seats for Hall D (180 seats: 10 rows × 18 seats)
INSERT INTO seats (hall_id, row_number, seat_number, seat_type)
SELECT 4, 
       CHR(65 + (seat_num / 18)),
       (seat_num % 18) + 1,
       'regular'
FROM generate_series(0, 179) AS seat_num;

-- Insert Seats for Hall E (120 seats: 8 rows × 15 seats)
INSERT INTO seats (hall_id, row_number, seat_number, seat_type)
SELECT 5, 
       CHR(65 + (seat_num / 15)),
       (seat_num % 15) + 1,
       CASE 
           WHEN seat_num < 30 THEN 'premium'
           ELSE 'regular'
       END
FROM generate_series(0, 119) AS seat_num;

-- =====================================================
-- Insert Showtimes
-- =====================================================
-- Today's showtimes
INSERT INTO showtimes (movie_id, hall_id, start_time, end_time, date, price) VALUES
-- The Matrix in Hall A
(1, 1, '10:00:00', '12:16:00', CURRENT_DATE, 450.00),
(1, 1, '13:00:00', '15:16:00', CURRENT_DATE, 450.00),
(1, 1, '16:00:00', '18:16:00', CURRENT_DATE, 500.00),
(1, 1, '19:00:00', '21:16:00', CURRENT_DATE, 500.00),

-- Inception in Hall B
(2, 2, '10:30:00', '12:58:00', CURRENT_DATE, 350.00),
(2, 2, '14:00:00', '16:28:00', CURRENT_DATE, 350.00),
(2, 2, '17:30:00', '19:58:00', CURRENT_DATE, 400.00),
(2, 2, '20:30:00', '22:58:00', CURRENT_DATE, 400.00),

-- The Dark Knight in Hall C (VIP)
(3, 3, '11:00:00', '13:32:00', CURRENT_DATE, 600.00),
(3, 3, '15:00:00', '17:32:00', CURRENT_DATE, 600.00),
(3, 3, '19:00:00', '21:32:00', CURRENT_DATE, 650.00),

-- Interstellar in Hall D
(4, 4, '12:00:00', '14:49:00', CURRENT_DATE, 400.00),
(4, 4, '16:00:00', '18:49:00', CURRENT_DATE, 400.00),
(4, 4, '20:00:00', '22:49:00', CURRENT_DATE, 450.00),

-- Tomorrow's showtimes
(5, 2, '10:00:00', '12:34:00', CURRENT_DATE + INTERVAL '1 day', 350.00),
(5, 2, '14:00:00', '16:34:00', CURRENT_DATE + INTERVAL '1 day', 350.00),
(5, 2, '18:00:00', '20:34:00', CURRENT_DATE + INTERVAL '1 day', 400.00),

(6, 4, '11:00:00', '13:22:00', CURRENT_DATE + INTERVAL '1 day', 350.00),
(6, 4, '15:00:00', '17:22:00', CURRENT_DATE + INTERVAL '1 day', 400.00),
(6, 4, '19:00:00', '21:22:00', CURRENT_DATE + INTERVAL '1 day', 400.00),

(7, 1, '10:30:00', '12:52:00', CURRENT_DATE + INTERVAL '1 day', 450.00),
(7, 1, '14:30:00', '16:52:00', CURRENT_DATE + INTERVAL '1 day', 450.00),
(7, 1, '18:30:00', '20:52:00', CURRENT_DATE + INTERVAL '1 day', 500.00),

(8, 5, '13:00:00', '15:23:00', CURRENT_DATE + INTERVAL '1 day', 400.00),
(8, 5, '17:00:00', '19:23:00', CURRENT_DATE + INTERVAL '1 day', 450.00),
(8, 5, '21:00:00', '23:23:00', CURRENT_DATE + INTERVAL '1 day', 450.00);

-- =====================================================
-- Insert Bookings
-- =====================================================
INSERT INTO bookings (user_id, showtime_id, total_amount, status) VALUES
(1, 1, 900.00, 'confirmed'),  -- John booked 2 tickets
(2, 1, 1350.00, 'confirmed'), -- Jane booked 3 tickets
(3, 3, 500.00, 'pending'),    -- Alice booked 1 ticket
(1, 5, 700.00, 'confirmed'),  -- John booked 2 tickets
(4, 10, 1200.00, 'confirmed'); -- Bob booked 3 VIP tickets

-- =====================================================
-- Insert Tickets
-- =====================================================
-- Tickets for booking 1 (John - 2 tickets for The Matrix 10:00)
INSERT INTO tickets (booking_id, seat_id, price, status) VALUES
(1, 1, 450.00, 'active'),   -- Seat A1
(1, 2, 450.00, 'active');   -- Seat A2

-- Tickets for booking 2 (Jane - 3 tickets for The Matrix 10:00)
INSERT INTO tickets (booking_id, seat_id, price, status) VALUES
(2, 16, 450.00, 'active'),  -- Seat B1
(2, 17, 450.00, 'active'),  -- Seat B2
(2, 18, 450.00, 'active');  -- Seat B3

-- Tickets for booking 3 (Alice - 1 ticket for The Matrix 16:00)
INSERT INTO tickets (booking_id, seat_id, price, status) VALUES
(3, 100, 500.00, 'active'); -- Seat G10

-- Tickets for booking 4 (John - 2 tickets for Inception 10:30)
INSERT INTO tickets (booking_id, seat_id, price, status) VALUES
(4, 151, 350.00, 'active'), -- Seat A1 in Hall B
(4, 152, 350.00, 'active'); -- Seat A2 in Hall B

-- Tickets for booking 5 (Bob - 3 VIP tickets for Interstellar 12:00)
INSERT INTO tickets (booking_id, seat_id, price, status) VALUES
(5, 481, 400.00, 'active'), -- Seat A1 in Hall D
(5, 482, 400.00, 'active'), -- Seat A2 in Hall D
(5, 483, 400.00, 'active'); -- Seat A3 in Hall D

-- =====================================================
-- Verify data insertion
-- =====================================================
SELECT 'Users: ' || COUNT(*) FROM users
UNION ALL
SELECT 'Movies: ' || COUNT(*) FROM movies
UNION ALL
SELECT 'Halls: ' || COUNT(*) FROM halls
UNION ALL
SELECT 'Seats: ' || COUNT(*) FROM seats
UNION ALL
SELECT 'Showtimes: ' || COUNT(*) FROM showtimes
UNION ALL
SELECT 'Bookings: ' || COUNT(*) FROM bookings
UNION ALL
SELECT 'Tickets: ' || COUNT(*) FROM tickets;

