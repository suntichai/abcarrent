-- AB CARRENT · MySQL 8.0 schema
-- Demo data shown in the browser prototype is stored in localStorage.
-- This schema is the relational starting point for a server-backed deployment.
CREATE DATABASE IF NOT EXISTS ab_carrent
  CHARACTER SET utf8mb4 COLLATE utf8mb4_thai_520_w2;
USE ab_carrent;

CREATE TABLE admins (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('owner','admin','staff') NOT NULL DEFAULT 'admin',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE cars (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  make_model VARCHAR(160) NOT NULL,
  plate_number VARCHAR(30) NOT NULL UNIQUE,
  car_type VARCHAR(40) NOT NULL,
  seats TINYINT UNSIGNED NOT NULL DEFAULT 5,
  transmission ENUM('automatic','manual') NOT NULL DEFAULT 'automatic',
  fuel_type VARCHAR(30) NOT NULL DEFAULT 'gasoline',
  engine_cc SMALLINT UNSIGNED NULL,
  color VARCHAR(40),
  daily_rate DECIMAL(10,2) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (daily_rate >= 0)
) ENGINE=InnoDB;

CREATE TABLE customers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(160) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(190),
  identity_number_encrypted VARBINARY(512),
  driver_license_number VARCHAR(80),
  address TEXT,
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_customers_phone (phone),
  INDEX idx_customers_name (full_name)
) ENGINE=InnoDB;

CREATE TABLE bookings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_number VARCHAR(32) NOT NULL UNIQUE,
  customer_id BIGINT UNSIGNED NOT NULL,
  car_id BIGINT UNSIGNED NOT NULL,
  pickup_at DATETIME NOT NULL,
  return_at DATETIME NOT NULL,
  rental_days DECIMAL(7,2) NOT NULL,
  daily_rate_snapshot DECIMAL(10,2) NOT NULL,
  rental_total DECIMAL(12,2) NOT NULL,
  deposit_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  payment_method VARCHAR(40),
  payment_status ENUM('unpaid','partial','paid','refunded') NOT NULL DEFAULT 'unpaid',
  booking_status ENUM('confirmed','ongoing','completed','cancelled') NOT NULL DEFAULT 'confirmed',
  notes TEXT,
  created_by BIGINT UNSIGNED,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CHECK (return_at > pickup_at),
  CHECK (rental_days > 0),
  CHECK (rental_total >= 0),
  CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_booking_car FOREIGN KEY (car_id) REFERENCES cars(id),
  CONSTRAINT fk_booking_admin FOREIGN KEY (created_by) REFERENCES admins(id) ON DELETE SET NULL,
  INDEX idx_booking_car_period (car_id, pickup_at, return_at),
  INDEX idx_booking_customer (customer_id),
  INDEX idx_booking_status_period (booking_status, pickup_at, return_at)
) ENGINE=InnoDB;

CREATE TABLE payments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id BIGINT UNSIGNED NOT NULL,
  payment_number VARCHAR(32) NOT NULL UNIQUE,
  payment_type ENUM('rental','deposit','refund','other') NOT NULL DEFAULT 'rental',
  amount DECIMAL(12,2) NOT NULL,
  method VARCHAR(40) NOT NULL,
  paid_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference_note VARCHAR(255),
  recorded_by BIGINT UNSIGNED,
  CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_payment_admin FOREIGN KEY (recorded_by) REFERENCES admins(id) ON DELETE SET NULL,
  CHECK (amount >= 0),
  INDEX idx_payment_paid_at (paid_at)
) ENGINE=InnoDB;

CREATE TABLE receipts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  receipt_number VARCHAR(32) NOT NULL UNIQUE,
  booking_id BIGINT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(12,2) NOT NULL,
  discount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL,
  customer_name_snapshot VARCHAR(160) NOT NULL,
  car_name_snapshot VARCHAR(160) NOT NULL,
  note VARCHAR(255),
  issued_by BIGINT UNSIGNED,
  CONSTRAINT fk_receipt_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
  CONSTRAINT fk_receipt_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
  CONSTRAINT fk_receipt_admin FOREIGN KEY (issued_by) REFERENCES admins(id) ON DELETE SET NULL,
  CHECK (total >= 0)
) ENGINE=InnoDB;

CREATE TABLE expenses (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  expense_number VARCHAR(32) NOT NULL UNIQUE,
  expense_date DATE NOT NULL,
  title VARCHAR(180) NOT NULL,
  category VARCHAR(60) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  payment_method VARCHAR(40),
  reference_note VARCHAR(255),
  recorded_by BIGINT UNSIGNED,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_expense_admin FOREIGN KEY (recorded_by) REFERENCES admins(id) ON DELETE SET NULL,
  CHECK (amount >= 0),
  INDEX idx_expense_date_category (expense_date, category)
) ENGINE=InnoDB;

-- Prevent overlapping active rentals inside the booking transaction:
-- SELECT id FROM cars WHERE id = ? FOR UPDATE;
-- SELECT id FROM bookings WHERE car_id = ?
--   AND booking_status IN ('confirmed','ongoing')
--   AND pickup_at < :requested_return AND return_at > :requested_pickup
--   FOR UPDATE;
-- Reject the insert when a row is returned, then insert the booking and any
-- initial payment/receipt before committing the transaction.
