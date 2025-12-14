-- =====================================================
-- Transaction Demonstrations
-- Online Cinema Ticket Booking System
-- =====================================================

\c cinema_booking;

-- =====================================================
-- Transaction 1: Complete Booking Process
-- This demonstrates ACID properties: Atomicity, Consistency, Isolation, Durability
-- =====================================================

BEGIN;

-- Step 1: Create a new booking
INSERT INTO bookings (user_id, showtime_id, total_amount, status)
VALUES (5, 2, 900.00, 'pending')
RETURNING booking_id;

-- Save the booking_id (let's assume it's 6 for this example)
-- In a real application, you would capture this from the RETURNING clause

-- Step 2: Add tickets for the booking
-- For demonstration, we'll use a variable approach
DO $$
DECLARE
    v_booking_id INTEGER;
    v_seat_price DECIMAL(10, 2);
    v_total DECIMAL(10, 2) := 0;
BEGIN
    -- Get the last booking_id
    SELECT MAX(booking_id) INTO v_booking_id FROM bookings;
    
    -- Insert first ticket
    SELECT price INTO v_seat_price FROM showtimes WHERE showtime_id = 2;
    INSERT INTO tickets (booking_id, seat_id, price, status)
    VALUES (v_booking_id, 30, v_seat_price, 'active');
    v_total := v_total + v_seat_price;
    
    -- Insert second ticket
    INSERT INTO tickets (booking_id, seat_id, price, status)
    VALUES (v_booking_id, 31, v_seat_price, 'active');
    v_total := v_total + v_seat_price;
    
    -- Update booking with correct total
    UPDATE bookings 
    SET total_amount = v_total, status = 'confirmed'
    WHERE booking_id = v_booking_id;
    
    RAISE NOTICE 'Booking % created successfully with total amount %', v_booking_id, v_total;
END $$;

-- Commit the transaction (all or nothing)
COMMIT;

-- Verify the booking
SELECT * FROM bookings WHERE booking_id = (SELECT MAX(booking_id) FROM bookings);
SELECT * FROM tickets WHERE booking_id = (SELECT MAX(booking_id) FROM bookings);

-- =====================================================
-- Transaction 2: Booking Cancellation (Rollback scenario)
-- =====================================================

BEGIN;

-- Try to cancel a booking and all its tickets
UPDATE bookings 
SET status = 'cancelled'
WHERE booking_id = 3;

UPDATE tickets
SET status = 'cancelled'
WHERE booking_id = 3;

-- Check the state
SELECT 'Booking cancelled' AS status, booking_id, status FROM bookings WHERE booking_id = 3;
SELECT 'Tickets cancelled' AS status, ticket_id, status FROM tickets WHERE booking_id = 3;

-- ROLLBACK to undo the cancellation (demonstration purpose)
ROLLBACK;

-- Verify rollback (status should be back to original)
SELECT 'After rollback' AS status, booking_id, status FROM bookings WHERE booking_id = 3;

-- =====================================================
-- Transaction 3: Seat Availability Check and Booking
-- Demonstrates isolation levels and preventing double booking
-- =====================================================

BEGIN;

-- Set isolation level to prevent dirty reads
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Check available seats for showtime 1
SELECT 
    se.seat_id,
    se.row_number,
    se.seat_number,
    CASE 
        WHEN t.ticket_id IS NULL OR t.status = 'cancelled' THEN 'Available'
        ELSE 'Booked'
    END AS status
FROM showtimes s
JOIN halls h ON s.hall_id = h.hall_id
JOIN seats se ON h.hall_id = se.hall_id
LEFT JOIN tickets t ON se.seat_id = t.seat_id
LEFT JOIN bookings b ON t.booking_id = b.booking_id 
    AND b.showtime_id = s.showtime_id 
    AND b.status != 'cancelled'
WHERE s.showtime_id = 1
    AND (t.ticket_id IS NULL OR t.status = 'cancelled' OR b.status = 'cancelled')
ORDER BY se.row_number, se.seat_number
LIMIT 2;

-- Book the first available seat (for demonstration)
-- In practice, this would be done with proper locking

COMMIT;

-- =====================================================
-- Transaction 4: Transfer Booking Between Users
-- =====================================================

BEGIN;

-- Update booking ownership
UPDATE bookings
SET user_id = 2
WHERE booking_id = 1 AND user_id = 1;

-- Verify the change
SELECT b.booking_id, u.name AS new_owner, b.total_amount
FROM bookings b
JOIN users u ON b.user_id = u.user_id
WHERE b.booking_id = 1;

-- If everything is correct, commit; otherwise rollback
COMMIT;

-- =====================================================
-- Transaction 5: Batch Ticket Purchase with Error Handling
-- =====================================================

BEGIN;

DO $$
DECLARE
    v_booking_id INTEGER;
    v_showtime_id INTEGER := 5;
    v_user_id INTEGER := 4;
    v_seat_ids INTEGER[] := ARRAY[160, 161, 162];
    v_seat_price DECIMAL(10, 2);
    v_total DECIMAL(10, 2) := 0;
    v_seat_id INTEGER;
    v_seat_available BOOLEAN;
BEGIN
    -- Get showtime price
    SELECT price INTO v_seat_price FROM showtimes WHERE showtime_id = v_showtime_id;
    
    -- Check seat availability first
    FOREACH v_seat_id IN ARRAY v_seat_ids
    LOOP
        -- Check if seat is available
        SELECT NOT EXISTS (
            SELECT 1 
            FROM tickets t
            JOIN bookings b ON t.booking_id = b.booking_id
            WHERE t.seat_id = v_seat_id
                AND b.showtime_id = v_showtime_id
                AND t.status = 'active'
                AND b.status != 'cancelled'
        ) INTO v_seat_available;
        
        IF NOT v_seat_available THEN
            RAISE EXCEPTION 'Seat % is already booked', v_seat_id;
        END IF;
    END LOOP;
    
    -- Create booking
    INSERT INTO bookings (user_id, showtime_id, total_amount, status)
    VALUES (v_user_id, v_showtime_id, v_seat_price * array_length(v_seat_ids, 1), 'pending')
    RETURNING booking_id INTO v_booking_id;
    
    -- Create tickets
    FOREACH v_seat_id IN ARRAY v_seat_ids
    LOOP
        INSERT INTO tickets (booking_id, seat_id, price, status)
        VALUES (v_booking_id, v_seat_id, v_seat_price, 'active');
        v_total := v_total + v_seat_price;
    END LOOP;
    
    -- Confirm booking
    UPDATE bookings 
    SET status = 'confirmed', total_amount = v_total
    WHERE booking_id = v_booking_id;
    
    RAISE NOTICE 'Successfully created booking % with % tickets', v_booking_id, array_length(v_seat_ids, 1);
END $$;

COMMIT;

-- =====================================================
-- Transaction 6: Price Update with Validation
-- =====================================================

BEGIN;

-- Update showtime prices for evening shows
UPDATE showtimes
SET price = price * 1.1  -- 10% increase
WHERE start_time >= '18:00:00'
    AND date >= CURRENT_DATE;

-- Verify the update
SELECT showtime_id, start_time, price, date
FROM showtimes
WHERE start_time >= '18:00:00'
    AND date >= CURRENT_DATE
ORDER BY date, start_time;

-- If satisfied, commit
COMMIT;

-- =====================================================
-- Transaction 7: Data Integrity Check
-- Demonstrates consistency checks within a transaction
-- =====================================================

BEGIN;

-- Check for orphaned tickets (tickets without valid bookings)
DO $$
DECLARE
    v_orphaned_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_orphaned_count
    FROM tickets t
    LEFT JOIN bookings b ON t.booking_id = b.booking_id
    WHERE b.booking_id IS NULL;
    
    IF v_orphaned_count > 0 THEN
        RAISE EXCEPTION 'Found % orphaned tickets. Data integrity violated!', v_orphaned_count;
    ELSE
        RAISE NOTICE 'Data integrity check passed. No orphaned tickets found.';
    END IF;
END $$;

-- Check for bookings with no tickets
DO $$
DECLARE
    v_empty_bookings INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_empty_bookings
    FROM bookings b
    LEFT JOIN tickets t ON b.booking_id = t.booking_id
    WHERE t.ticket_id IS NULL;
    
    IF v_empty_bookings > 0 THEN
        RAISE NOTICE 'Found % bookings without tickets', v_empty_bookings;
    END IF;
END $$;

COMMIT;

-- =====================================================
-- Transaction 8: Concurrent Booking Simulation
-- Demonstrates isolation levels
-- =====================================================

-- Terminal 1 (Session 1)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT * FROM tickets 
WHERE booking_id IN (
    SELECT booking_id FROM bookings WHERE showtime_id = 1
)
FOR UPDATE;

-- Terminal 2 (Session 2) - Run simultaneously
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- This will wait until Session 1 commits or rollbacks
SELECT * FROM tickets 
WHERE booking_id IN (
    SELECT booking_id FROM bookings WHERE showtime_id = 1
)
FOR UPDATE;

-- Session 1 commits first
COMMIT;

-- Session 2 can now proceed
COMMIT;

-- =====================================================
-- Transaction 9: Savepoint Demonstration
-- =====================================================

BEGIN;

-- Create initial state
INSERT INTO bookings (user_id, showtime_id, total_amount, status)
VALUES (3, 6, 350.00, 'pending')
RETURNING booking_id;

-- Create savepoint
SAVEPOINT before_tickets;

-- Add first ticket
DO $$
DECLARE
    v_booking_id INTEGER;
    v_price DECIMAL(10, 2);
BEGIN
    SELECT MAX(booking_id) INTO v_booking_id FROM bookings;
    SELECT price INTO v_price FROM showtimes WHERE showtime_id = 6;
    
    INSERT INTO tickets (booking_id, seat_id, price, status)
    VALUES (v_booking_id, 170, v_price, 'active');
END $$;

-- Create another savepoint
SAVEPOINT before_second_ticket;

-- Try to add second ticket to same seat (will fail due to trigger)
DO $$
DECLARE
    v_booking_id INTEGER;
    v_price DECIMAL(10, 2);
BEGIN
    SELECT MAX(booking_id) INTO v_booking_id FROM bookings;
    SELECT price INTO v_price FROM showtimes WHERE showtime_id = 6;
    
    BEGIN
        INSERT INTO tickets (booking_id, seat_id, price, status)
        VALUES (v_booking_id, 170, v_price, 'active');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error occurred: %', SQLERRM;
        ROLLBACK TO SAVEPOINT before_second_ticket;
    END;
END $$;

-- Rollback to savepoint (keeps first ticket)
-- ROLLBACK TO SAVEPOINT before_second_ticket;

-- Or commit the transaction
COMMIT;

-- =====================================================
-- Transaction 10: Multi-table Update with Constraints
-- =====================================================

BEGIN;

-- Update movie information and cascade to showtimes
-- (Note: In our schema, price is in showtimes, not movies)
-- So we'll demonstrate by updating showtimes based on movie

UPDATE showtimes
SET price = price * 1.15  -- 15% increase for premium movies
WHERE movie_id IN (
    SELECT movie_id FROM movies WHERE rating = 'R'
)
AND date >= CURRENT_DATE;

-- Update bookings total if they're still pending
UPDATE bookings b
SET total_amount = (
    SELECT SUM(t.price)
    FROM tickets t
    WHERE t.booking_id = b.booking_id
)
WHERE b.status = 'pending'
AND EXISTS (
    SELECT 1 FROM tickets t WHERE t.booking_id = b.booking_id
);

COMMIT;

