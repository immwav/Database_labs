-- =====================================================
-- Online Cinema Ticket Booking System
-- Database Schema Implementation
-- =====================================================

-- Drop database if exists (for clean setup)
DROP DATABASE IF EXISTS cinema_booking;

-- Create database
CREATE DATABASE cinema_booking;

-- Connect to the database
\c cinema_booking;

-- =====================================================
-- Enable UUID extension
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- Table: users
-- Stores user account information
-- =====================================================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- =====================================================
-- Table: movies
-- Stores movie information
-- =====================================================
CREATE TABLE movies (
    movie_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    genre VARCHAR(50) NOT NULL,
    duration INTEGER NOT NULL CHECK (duration > 0),
    rating VARCHAR(10) CHECK (rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17', 'NR')),
    description TEXT,
    release_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Table: halls
-- Stores cinema hall information
-- =====================================================
CREATE TABLE halls (
    hall_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    screen_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Table: seats
-- Stores seat information for each hall
-- =====================================================
CREATE TABLE seats (
    seat_id SERIAL PRIMARY KEY,
    hall_id INTEGER NOT NULL,
    row_number VARCHAR(5) NOT NULL,
    seat_number INTEGER NOT NULL,
    seat_type VARCHAR(20) DEFAULT 'regular' CHECK (seat_type IN ('regular', 'VIP', 'premium')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hall_id) REFERENCES halls(hall_id) ON DELETE CASCADE,
    CONSTRAINT unique_seat_per_hall UNIQUE (hall_id, row_number, seat_number)
);

-- =====================================================
-- Table: showtimes
-- Stores movie showtime information
-- =====================================================
CREATE TABLE showtimes (
    showtime_id SERIAL PRIMARY KEY,
    movie_id INTEGER NOT NULL,
    hall_id INTEGER NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    date DATE NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE,
    FOREIGN KEY (hall_id) REFERENCES halls(hall_id) ON DELETE CASCADE,
    CONSTRAINT valid_time_range CHECK (end_time > start_time),
    CONSTRAINT no_overlapping_showtimes UNIQUE (hall_id, date, start_time)
);

-- =====================================================
-- Table: bookings
-- Stores booking information
-- =====================================================
CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    showtime_id INTEGER NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (showtime_id) REFERENCES showtimes(showtime_id) ON DELETE CASCADE
);

-- =====================================================
-- Table: tickets
-- Stores individual ticket information
-- =====================================================
CREATE TABLE tickets (
    ticket_id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL,
    seat_id INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE,
    FOREIGN KEY (seat_id) REFERENCES seats(seat_id) ON DELETE CASCADE
);

-- =====================================================
-- Create indexes for better query performance
-- =====================================================

-- Indexes on foreign keys
CREATE INDEX idx_seats_hall_id ON seats(hall_id);
CREATE INDEX idx_showtimes_movie_id ON showtimes(movie_id);
CREATE INDEX idx_showtimes_hall_id ON showtimes(hall_id);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_showtime_id ON bookings(showtime_id);
CREATE INDEX idx_tickets_booking_id ON tickets(booking_id);
CREATE INDEX idx_tickets_seat_id ON tickets(seat_id);

-- Indexes on frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_showtimes_date ON showtimes(date);
CREATE INDEX idx_showtimes_date_time ON showtimes(date, start_time);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_movies_genre ON movies(genre);
CREATE INDEX idx_movies_release_date ON movies(release_date);

-- Composite index for seat availability checks
CREATE INDEX idx_tickets_booking_seat ON tickets(booking_id, seat_id, status);

-- =====================================================
-- Create function to update updated_at timestamp
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- =====================================================
-- Create trigger to auto-update updated_at
-- =====================================================
CREATE TRIGGER update_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Create function to validate seat availability
-- =====================================================
CREATE OR REPLACE FUNCTION check_seat_availability()
RETURNS TRIGGER AS $$
DECLARE
    v_showtime_id INTEGER;
    v_seat_taken INTEGER;
BEGIN
    -- Get showtime_id from booking
    SELECT showtime_id INTO v_showtime_id
    FROM bookings
    WHERE booking_id = NEW.booking_id;
    
    -- Check if seat is already taken for this showtime
    SELECT COUNT(*) INTO v_seat_taken
    FROM tickets t
    JOIN bookings b ON t.booking_id = b.booking_id
    WHERE b.showtime_id = v_showtime_id
      AND t.seat_id = NEW.seat_id
      AND t.status = 'active'
      AND b.status != 'cancelled';
    
    IF v_seat_taken > 0 THEN
        RAISE EXCEPTION 'Seat is already booked for this showtime';
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- =====================================================
-- Create trigger to prevent double booking
-- =====================================================
CREATE TRIGGER check_seat_before_insert
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION check_seat_availability();

-- =====================================================
-- Create view for available seats per showtime
-- =====================================================
CREATE OR REPLACE VIEW available_seats_view AS
SELECT 
    s.showtime_id,
    st.hall_id,
    st.date,
    s.seat_id,
    se.row_number,
    se.seat_number,
    se.seat_type,
    CASE 
        WHEN t.ticket_id IS NULL OR (t.status = 'cancelled' OR b.status = 'cancelled') THEN true
        ELSE false
    END AS is_available
FROM showtimes s
CROSS JOIN seats se
LEFT JOIN tickets t ON se.seat_id = t.seat_id
LEFT JOIN bookings b ON t.booking_id = b.booking_id AND b.showtime_id = s.showtime_id
JOIN showtimes st ON s.showtime_id = st.showtime_id
WHERE se.hall_id = s.hall_id;

-- =====================================================
-- Create view for booking details
-- =====================================================
CREATE OR REPLACE VIEW booking_details_view AS
SELECT 
    b.booking_id,
    b.user_id,
    u.name AS user_name,
    u.email AS user_email,
    b.showtime_id,
    m.title AS movie_title,
    m.genre,
    m.duration,
    h.name AS hall_name,
    s.date AS show_date,
    s.start_time,
    s.end_time,
    b.total_amount,
    b.status AS booking_status,
    b.created_at AS booking_created_at,
    COUNT(t.ticket_id) AS ticket_count
FROM bookings b
JOIN users u ON b.user_id = u.user_id
JOIN showtimes s ON b.showtime_id = s.showtime_id
JOIN movies m ON s.movie_id = m.movie_id
JOIN halls h ON s.hall_id = h.hall_id
LEFT JOIN tickets t ON b.booking_id = t.booking_id AND t.status = 'active'
GROUP BY b.booking_id, u.name, u.email, m.title, m.genre, m.duration, 
         h.name, s.date, s.start_time, s.end_time, b.total_amount, b.status, b.created_at;

-- =====================================================
-- Grant permissions (if needed for multiple users)
-- =====================================================
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cinema_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cinema_user;

