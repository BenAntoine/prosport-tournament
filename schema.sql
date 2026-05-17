-- ==========================================
-- DATABASE BLUEPRINT: PROSPORT TOURNAMENT
-- Course: Database Management Systems (DBMS / SGBD)
-- Developer: Ben Antoine Manongi (ID: 2220600)
-- Database Engine: PostgreSQL (Supabase Compatible)
-- ==========================================

-- Clean up existing database objects for a safe, re-runnable script
DROP TRIGGER IF EXISTS trg_after_registration_confirm ON registrations;
DROP FUNCTION IF EXISTS update_team_players_count();
DROP FUNCTION IF EXISTS get_total_confirmed_revenue();

DROP TABLE IF EXISTS registrations CASCADE;
DROP TABLE IF EXISTS medical_incidents CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS venues CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- ==========================================
-- 1. DATA DEFINITION LANGUAGE (DDL)
-- ==========================================

-- Table 1: Venues (Stadiums and Arenas)
CREATE TABLE venues (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),
    surface_type VARCHAR(100), -- e.g., Grass, Hardwood Court, PVC Taraflex
    main_sport VARCHAR(100),   -- e.g., Football, Basketball, Volleyball
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table 2: Teams
CREATE TABLE teams (
    id SERIAL PRIMARY KEY,
    venue_id INT REFERENCES venues(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL UNIQUE,
    coach VARCHAR(255) NOT NULL,
    founded_year INT CHECK (founded_year >= 1800 AND founded_year <= 2026),
    category VARCHAR(50) CHECK (category IN ('pro', 'amateur', 'youth', 'varsity')),
    registration_fee NUMERIC(10,2) NOT NULL CHECK (registration_fee >= 0),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'eliminated', 'pending', 'inactive')),
    image_url TEXT,
    description TEXT,
    sport VARCHAR(100) NOT NULL,
    home_city VARCHAR(100),
    players_count INT DEFAULT 0 CHECK (players_count >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table 3: Matches (Tournament Schedule)
CREATE TABLE matches (
    id SERIAL PRIMARY KEY,
    team1_id INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    team2_id INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    venue_id INT REFERENCES venues(id) ON DELETE SET NULL,
    match_date DATE NOT NULL,
    match_time TIME NOT NULL,
    team1_score INT CHECK (team1_score >= 0),
    team2_score INT CHECK (team2_score >= 0),
    status VARCHAR(50) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    sport VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_different_teams CHECK (team1_id <> team2_id)
);

-- Table 4: Medical Incidents & Asset Log
CREATE TABLE medical_incidents (
    id SERIAL PRIMARY KEY,
    team_id INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN ('medical', 'technical')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'resolved')),
    cost NUMERIC(10,2) DEFAULT 0 CHECK (cost >= 0),
    reported_date DATE NOT NULL,
    resolved_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table 5: Subscriptions (Registrations)
CREATE TABLE registrations (
    id SERIAL PRIMARY KEY,
    team_id INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    sport VARCHAR(100) NOT NULL,
    captain_name VARCHAR(255) NOT NULL,
    players_count INT NOT NULL CHECK (players_count >= 5),
    registration_date DATE DEFAULT CURRENT_DATE,
    total_cost NUMERIC(10,2) NOT NULL CHECK (total_cost >= 0),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('confirmed', 'pending', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table 6: Profiles (Links to Supabase auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY, -- References auth.users.id
    full_name VARCHAR(255),
    phone VARCHAR(100),
    id_number VARCHAR(100) UNIQUE, -- Sports licence identifier
    role VARCHAR(50) DEFAULT 'customer' CHECK (role IN ('customer', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- 2. PROCEDURAL LOGIC: STORED FUNCTIONS & TRIGGERS
-- ==========================================

-- Stored Function: Compute cumulative confirmed registration revenue
CREATE OR REPLACE FUNCTION get_total_confirmed_revenue()
RETURNS NUMERIC(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_revenue NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(total_cost), 0)
    INTO v_revenue
    FROM registrations
    WHERE status = 'confirmed';
    
    RETURN v_revenue;
END;
$$;

-- Trigger Function: Auto-increment registered players count in the team upon confirmed sign-up
CREATE OR REPLACE FUNCTION update_team_players_count()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    IF (NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status <> 'confirmed')) THEN
        UPDATE teams
        SET players_count = players_count + NEW.players_count
        WHERE id = NEW.team_id;
    END IF;
    RETURN NEW;
END;
$$;

-- Bind Trigger to registrations table
CREATE TRIGGER trg_after_registration_confirm
AFTER INSERT OR UPDATE ON registrations
FOR EACH ROW
EXECUTE FUNCTION update_team_players_count();

-- ==========================================
-- 3. DATA MANIPULATION LANGUAGE (DML) - SAMPLE SEEDS
-- ==========================================

-- Insertion of Stadiums and Venues
INSERT INTO venues (name, address, city, capacity, surface_type, main_sport) VALUES
('Olympic Metropolitan Stadium', '1 Sport Avenue', 'Paris', 80000, 'Natural Grass', 'Football'),
('Titans Arena', '15 Basket Blvd', 'Lyon', 15000, 'Polished Hardwood', 'Basketball'),
('Eagles Park', '50 Victory Road', 'Marseille', 60000, 'Synthetic Turf', 'Football'),
('Coastal Gymnasium', '8 Fishnet Promenade', 'Nice', 5000, 'Taraflex PVC', 'Volleyball');

-- Insertion of Sports Teams
INSERT INTO teams (venue_id, name, coach, founded_year, category, registration_fee, status, image_url, description, sport, home_city, players_count) VALUES
(1, 'Metropolis Strikers', 'Jean-Pierre Silva', 2015, 'pro', 250.00, 'active', 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=600&q=80', 'Defending regional champions, highly praised for their tactical ball possession.', 'Football', 'Paris', 18),
(2, 'Apex Titans', 'Sarah Dupont', 2018, 'pro', 300.00, 'active', 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=600&q=80', 'An athletic roster showing a bulletproof defensive block.', 'Basketball', 'Lyon', 12),
(3, 'Vanguard Eagles', 'Marc-André Lavoie', 2020, 'varsity', 200.00, 'active', 'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=600&q=80', 'Energetic varsity team with excellent group cohesion.', 'Football', 'Marseille', 22),
(4, 'Coastal Mavericks', 'Hélène Rocher', 2021, 'amateur', 150.00, 'pending', 'https://images.unsplash.com/photo-1592656094267-764a45068526?auto=format&fit=crop&w=600&q=80', 'Passionate local sports squad ready to challenge division favorites.', 'Volleyball', 'Nice', 10);

-- Insertion of Scheduled and Completed Matches
INSERT INTO matches (team1_id, team2_id, venue_id, match_date, match_time, team1_score, team2_score, status, sport) VALUES
(1, 3, 1, '2026-05-20', '20:45:00', NULL, NULL, 'scheduled', 'Football'),
(2, 4, 2, '2026-05-17', '18:30:00', 88, 82, 'completed', 'Basketball');

-- Insertion of Medical and Technical Incident Reports
INSERT INTO medical_incidents (team_id, type, title, description, status, cost, reported_date) VALUES
(1, 'medical', 'Hamstring strain (Striker)', 'Injury sustained during active play in the 75th minute. Full rest and physical rehabilitation prescribed.', 'in_progress', 180.00, '2026-05-12'),
(2, 'technical', 'GPS Smart performance tracking bibs acquisition', 'Acquisition of 15 bio-sensors for cardiac rate tracking and telemetry analysis.', 'resolved', 1450.00, '2026-05-02');

-- Insertion of a Sample Subscription
INSERT INTO registrations (team_id, sport, captain_name, players_count, registration_date, total_cost, status) VALUES
(1, 'Football', 'Robert Smith', 18, '2026-05-10', 250.00, 'confirmed');
