-- ============================================================
--  WORKLOAD MONITORING DATABASE FOR INDIAN NATIONAL CRICKETERS
-- ============================================================

-- ============================================================
-- SECTION 1: DESIGN OVERVIEW
-- ============================================================
-- ENTITIES & RELATIONSHIPS:
--   Players           1:M  Workload_Records
--   Matches           1:M  Workload_Records
--   Training_Sessions 1:M  Workload_Records
--   Coaches           1:M  Training_Sessions
--   Players           1:M  Injuries
--   Players           1:M  Recovery_Sessions
--   Players           1:M  Workload_Alerts
--
-- NORMALIZATION: All tables are in 3NF/BCNF
--   - No partial dependencies (all non-key attrs depend on full PK)
--   - No transitive dependencies
-- ============================================================

DROP DATABASE IF EXISTS cricket_workload;
CREATE DATABASE cricket_workload;
USE cricket_workload;

-- ============================================================
-- SECTION 2: SCHEMA / TABLE CREATION
-- ============================================================

-- TABLE 1: Players
CREATE TABLE Players (
    player_id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name        VARCHAR(100)  NOT NULL,
    date_of_birth    DATE          NOT NULL,
    role             ENUM('Batsman','Bowler','All-Rounder','Wicket-Keeper') NOT NULL,
    batting_style    ENUM('Right-Hand','Left-Hand') NOT NULL,
    bowling_style    VARCHAR(50)   DEFAULT NULL,
    status           ENUM('Active','Injured','Resting','Retired') NOT NULL DEFAULT 'Active',
    jersey_number    TINYINT UNSIGNED NOT NULL,
    ipl_team         VARCHAR(60)   DEFAULT NULL,
    created_at       TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_jersey UNIQUE (jersey_number)
);
CREATE INDEX idx_players_status ON Players(status);
CREATE INDEX idx_players_role   ON Players(role);

-- TABLE 2: Coaches
CREATE TABLE Coaches (
    coach_id         INT AUTO_INCREMENT PRIMARY KEY,
    full_name        VARCHAR(100)  NOT NULL,
    specialization   ENUM('Batting','Bowling','Fielding','Fitness','Head Coach') NOT NULL,
    years_experience TINYINT UNSIGNED NOT NULL,
    email            VARCHAR(100)  NOT NULL,
    phone            VARCHAR(15)   DEFAULT NULL,
    CONSTRAINT chk_exp  CHECK (years_experience >= 0),
    CONSTRAINT uq_email UNIQUE (email)
);

-- TABLE 3: Matches
CREATE TABLE Matches (
    match_id     INT AUTO_INCREMENT PRIMARY KEY,
    match_date   DATE           NOT NULL,
    opponent     VARCHAR(80)    NOT NULL,
    venue        VARCHAR(120)   NOT NULL,
    format       ENUM('Test','ODI','T20I') NOT NULL,
    result       ENUM('Won','Lost','Draw','No Result','Tied') DEFAULT NULL,
    total_overs  DECIMAL(5,1)   DEFAULT NULL,
    CONSTRAINT chk_overs CHECK (total_overs IS NULL OR total_overs > 0)
);
CREATE INDEX idx_matches_date   ON Matches(match_date);
CREATE INDEX idx_matches_format ON Matches(format);

-- TABLE 4: Training_Sessions
CREATE TABLE Training_Sessions (
    session_id    INT AUTO_INCREMENT PRIMARY KEY,
    coach_id      INT           NOT NULL,
    session_date  DATE          NOT NULL,
    session_type  ENUM('Batting','Bowling','Fielding','Fitness','Recovery','Tactical') NOT NULL,
    duration_mins SMALLINT UNSIGNED NOT NULL,
    intensity     ENUM('Low','Moderate','High','Very High') NOT NULL,
    location      VARCHAR(100)  NOT NULL,
    notes         TEXT          DEFAULT NULL,
    CONSTRAINT fk_ts_coach  FOREIGN KEY (coach_id) REFERENCES Coaches(coach_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_duration CHECK (duration_mins BETWEEN 15 AND 480)
);
CREATE INDEX idx_ts_coach ON Training_Sessions(coach_id);
CREATE INDEX idx_ts_date  ON Training_Sessions(session_date);

-- TABLE 5: Workload_Records
-- FIX: This is the single correct definition of Workload_Records.
-- It uses workload_score + source_type + notes (no balls_bowled / overs_fielded / batting_mins / rpe).
-- All triggers, procedures, functions, and UPDATE statements are written to match this schema.
CREATE TABLE Workload_Records (
    record_id      INT AUTO_INCREMENT PRIMARY KEY,
    player_id      INT           NOT NULL,
    match_id       INT           DEFAULT NULL,
    session_id     INT           DEFAULT NULL,
    record_date    DATE          NOT NULL,
    workload_score DECIMAL(6,2)  NOT NULL DEFAULT 0.00,
    source_type    ENUM('Match','Training') NOT NULL,
    notes          VARCHAR(255)  DEFAULT NULL,
    CONSTRAINT fk_wr_player  FOREIGN KEY (player_id)  REFERENCES Players(player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_wr_match   FOREIGN KEY (match_id)   REFERENCES Matches(match_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_wr_session FOREIGN KEY (session_id) REFERENCES Training_Sessions(session_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_wr_score  CHECK (workload_score >= 0)
    -- Note: source consistency (match_id/session_id vs source_type) is enforced by trigger trg_wr_source_check
    -- MySQL (Error 3823) does not allow FK columns inside CHECK constraints
);
CREATE INDEX idx_wr_player      ON Workload_Records(player_id);
CREATE INDEX idx_wr_date        ON Workload_Records(record_date);
CREATE INDEX idx_wr_match       ON Workload_Records(match_id);
CREATE INDEX idx_wr_player_date ON Workload_Records(player_id, record_date);

-- TABLE 6: Injuries
CREATE TABLE Injuries (
    injury_id              INT AUTO_INCREMENT PRIMARY KEY,
    player_id              INT          NOT NULL,
    injury_date            DATE         NOT NULL,
    body_part              VARCHAR(60)  NOT NULL,
    injury_type            VARCHAR(80)  NOT NULL,
    severity               ENUM('Mild','Moderate','Severe','Critical') NOT NULL,
    expected_recovery_days INT UNSIGNED DEFAULT NULL,
    actual_recovery_days   INT UNSIGNED DEFAULT NULL,
    is_recovered           TINYINT(1)   NOT NULL DEFAULT 0,
    notes                  TEXT         DEFAULT NULL,
    CONSTRAINT fk_inj_player FOREIGN KEY (player_id) REFERENCES Players(player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_inj_player   ON Injuries(player_id);
CREATE INDEX idx_inj_severity ON Injuries(severity);

-- TABLE 7: Recovery_Sessions
CREATE TABLE Recovery_Sessions (
    recovery_id   INT AUTO_INCREMENT PRIMARY KEY,
    player_id     INT           NOT NULL,
    injury_id     INT           DEFAULT NULL,
    session_date  DATE          NOT NULL,
    recovery_type ENUM('Physiotherapy','Ice Bath','Rest','Yoga','Pool Session',
                       'Massage','Gym Rehab','Stretching') NOT NULL,
    duration_mins SMALLINT UNSIGNED NOT NULL,
    pain_level    TINYINT UNSIGNED  DEFAULT NULL,
    recovery_score DECIMAL(5,2)     DEFAULT NULL,
    conducted_by  VARCHAR(100)  DEFAULT NULL,
    CONSTRAINT fk_rs_player FOREIGN KEY (player_id)  REFERENCES Players(player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rs_injury FOREIGN KEY (injury_id)  REFERENCES Injuries(injury_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_pain   CHECK (pain_level IS NULL OR pain_level BETWEEN 0 AND 10),
    CONSTRAINT chk_rs_dur CHECK (duration_mins BETWEEN 10 AND 300)
);
CREATE INDEX idx_rs_player ON Recovery_Sessions(player_id);
CREATE INDEX idx_rs_date   ON Recovery_Sessions(session_date);

-- TABLE 8: Workload_Alerts
CREATE TABLE Workload_Alerts (
    alert_id        INT AUTO_INCREMENT PRIMARY KEY,
    player_id       INT          NOT NULL,
    alert_date      DATE         NOT NULL,
    alert_type      ENUM('Overload','Injury Risk','High Fatigue',
                         'Consecutive Days','Spike Warning') NOT NULL,
    alert_message   VARCHAR(255) NOT NULL,
    triggered_score DECIMAL(6,2) DEFAULT NULL,
    threshold_value DECIMAL(6,2) DEFAULT NULL,
    is_resolved     TINYINT(1)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_wa_player FOREIGN KEY (player_id) REFERENCES Players(player_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_wa_player         ON Workload_Alerts(player_id);
CREATE INDEX idx_wa_resolved       ON Workload_Alerts(is_resolved);
CREATE INDEX idx_wa_player_resolved ON Workload_Alerts(player_id, is_resolved);


-- ============================================================
-- SECTION 3: SAMPLE DATA
-- ============================================================

INSERT INTO Coaches (full_name, specialization, years_experience, email, phone) VALUES
('Gautam Gambhir',  'Head Coach', 18, 'gambhir@bcci.in',  '9810000001'),
('Paras Mhambrey',  'Bowling',    14, 'mhambrey@bcci.in', '9810000002'),
('Vikram Rathour',  'Batting',    16, 'rathour@bcci.in',  '9810000003'),
('T. Dilip',        'Fielding',   12, 'dilip@bcci.in',    '9810000004'),
('Soham Desai',     'Fitness',    10, 'desai@bcci.in',    '9810000005');

INSERT INTO Players (full_name, date_of_birth, role, batting_style, bowling_style, status, jersey_number, ipl_team) VALUES
('Rohit Sharma',     '1987-04-30', 'Batsman',       'Right-Hand', NULL,                    'Active',  45, 'Mumbai Indians'),
('Virat Kohli',      '1988-11-05', 'Batsman',       'Right-Hand', NULL,                    'Active',  18, 'Royal Challengers Bangalore'),
('Jasprit Bumrah',   '1993-12-06', 'Bowler',        'Right-Hand', 'Right-Arm Fast',        'Active',  93, 'Mumbai Indians'),
('Ravindra Jadeja',  '1988-12-06', 'All-Rounder',   'Left-Hand',  'Left-Arm Orthodox',     'Active',  20, 'Chennai Super Kings'),
('KL Rahul',         '1992-04-18', 'Wicket-Keeper', 'Right-Hand', NULL,                    'Active',   1, 'Lucknow Super Giants'),
('Mohammed Shami',   '1990-09-03', 'Bowler',        'Right-Hand', 'Right-Arm Fast-Medium', 'Injured', 11, 'Gujarat Titans'),
('Suryakumar Yadav', '1990-09-22', 'Batsman',       'Right-Hand', NULL,                    'Active',  63, 'Mumbai Indians'),
('Hardik Pandya',    '1993-10-11', 'All-Rounder',   'Right-Hand', 'Right-Arm Medium-Fast', 'Active',  33, 'Mumbai Indians'),
('Axar Patel',       '1994-01-20', 'All-Rounder',   'Left-Hand',  'Left-Arm Orthodox',     'Active',   2, 'Delhi Capitals'),
('Shreyas Iyer',     '1994-12-06', 'Batsman',       'Right-Hand', NULL,                    'Resting', 41, 'Kolkata Knight Riders');

INSERT INTO Matches (match_date, opponent, venue, format, result, total_overs) VALUES
('2024-11-22', 'Australia',   'Optus Stadium, Perth',             'Test', 'Lost',  NULL),
('2024-11-28', 'Australia',   'Adelaide Oval, Adelaide',          'Test', 'Won',   NULL),
('2024-12-06', 'Australia',   'Gabba, Brisbane',                  'Test', 'Draw',  NULL),
('2024-12-26', 'Australia',   'MCG, Melbourne',                   'Test', 'Lost',  NULL),
('2025-01-03', 'Australia',   'SCG, Sydney',                      'Test', 'Lost',  NULL),
('2025-02-09', 'England',     'Eden Gardens, Kolkata',            'T20I', 'Won',   20.0),
('2025-02-12', 'England',     'Wankhede Stadium, Mumbai',         'T20I', 'Won',   20.0),
('2025-02-15', 'England',     'Narendra Modi Stadium, Ahmedabad', 'T20I', 'Won',   18.3),
('2025-03-02', 'South Africa','PCA Stadium, Mohali',              'ODI',  'Won',   45.2),
('2025-03-05', 'South Africa','Sawai Mansingh, Jaipur',           'ODI',  'Won',   50.0);

INSERT INTO Training_Sessions (coach_id, session_date, session_type, duration_mins, intensity, location, notes) VALUES
(2, '2024-11-18', 'Bowling',  90,  'High',     'WACA, Perth',        'Fast bowling nets'),
(3, '2024-11-19', 'Batting',  120, 'High',     'WACA, Perth',        'Match simulation'),
(4, '2024-11-20', 'Fielding', 60,  'Moderate', 'WACA, Perth',        'Catching and diving drills'),
(5, '2024-11-21', 'Fitness',  75,  'High',     'WACA Gym, Perth',    'Pre-match conditioning'),
(2, '2024-11-25', 'Bowling',  80,  'Moderate', 'Adelaide Oval',      'Line and length work'),
(3, '2024-11-26', 'Batting',  100, 'High',     'Adelaide Oval',      'Spin and pace practice'),
(5, '2024-12-03', 'Recovery', 60,  'Low',      'Brisbane Hotel Gym', 'Post-test recovery'),
(5, '2024-12-04', 'Fitness',  90,  'Moderate', 'Gabba, Brisbane',    'Conditioning session'),
(3, '2025-02-07', 'Batting',  110, 'High',     'Eden Nets, Kolkata', 'T20 game plan'),
(2, '2025-02-08', 'Bowling',  70,  'High',     'Eden Nets, Kolkata', 'Death bowling drills'),
(4, '2025-03-01', 'Fielding', 80,  'Moderate', 'PCA Nets, Mohali',   'Ground fielding'),
(5, '2025-03-01', 'Fitness',  60,  'Moderate', 'PCA Gym, Mohali',    'Pre-series conditioning');

-- Workload Records (Match-based)
INSERT INTO Workload_Records (player_id, match_id, session_id, record_date, workload_score, source_type, notes) VALUES
(1, 1,  NULL, '2024-11-22', 185.50, 'Match',    'Test Perth Day 1 - batting'),
(2, 1,  NULL, '2024-11-22', 210.00, 'Match',    'Test Perth - top scorer'),
(3, 1,  NULL, '2024-11-22', 295.00, 'Match',    'Test Perth - heavy bowling spell'),
(4, 1,  NULL, '2024-11-22', 230.50, 'Match',    'Test Perth - all-round'),
(5, 1,  NULL, '2024-11-22', 170.20, 'Match',    'Test Perth - wicket keeper'),
(1, 2,  NULL, '2024-11-28', 220.00, 'Match',    'Test Adelaide - century stand'),
(2, 2,  NULL, '2024-11-28', 260.00, 'Match',    'Test Adelaide - match winner'),
(3, 2,  NULL, '2024-11-28', 280.00, 'Match',    'Test Adelaide - 5-fer'),
(4, 2,  NULL, '2024-11-28', 240.00, 'Match',    'Test Adelaide - 80 runs + 3 wkts'),
(8, 2,  NULL, '2024-11-28', 200.00, 'Match',    'Test Adelaide - Pandya all-round'),
(3, 3,  NULL, '2024-12-06', 310.00, 'Match',    'Test Brisbane - Bumrah overload'),
(4, 3,  NULL, '2024-12-06', 255.00, 'Match',    'Test Brisbane - Jadeja fatigue'),
(8, 3,  NULL, '2024-12-06', 180.00, 'Match',    'Test Brisbane - Pandya moderate'),
(1, 4,  NULL, '2024-12-26', 150.00, 'Match',    'Test MCG - early dismissal'),
(2, 4,  NULL, '2024-12-26', 140.00, 'Match',    'Test MCG - poor form'),
(3, 4,  NULL, '2024-12-26', 320.00, 'Match',    'Test MCG - Bumrah critical load'),
(4, 4,  NULL, '2024-12-26', 215.00, 'Match',    'Test MCG - Jadeja 50 + 2 wkts'),
(1, 6,  NULL, '2025-02-09', 95.00,  'Match',    'T20 Kolkata - Rohit quickfire'),
(2, 6,  NULL, '2025-02-09', 88.00,  'Match',    'T20 Kolkata - Kohli cameo'),
(7, 6,  NULL, '2025-02-09', 120.00, 'Match',    'T20 Kolkata - SKY fireworks'),
(8, 6,  NULL, '2025-02-09', 110.00, 'Match',    'T20 Kolkata - Pandya finish'),
(9, 6,  NULL, '2025-02-09', 100.00, 'Match',    'T20 Kolkata - Axar economy'),
(1, 9,  NULL, '2025-03-02', 175.00, 'Match',    'ODI Mohali - Rohit 55'),
(2, 9,  NULL, '2025-03-02', 220.00, 'Match',    'ODI Mohali - Kohli 82'),
(3, 9,  NULL, '2025-03-02', 190.00, 'Match',    'ODI Mohali - Bumrah 3 wkts'),
(4, 9,  NULL, '2025-03-02', 160.00, 'Match',    'ODI Mohali - Jadeja 22 + 2 wkts'),
(5, 9,  NULL, '2025-03-02', 130.00, 'Match',    'ODI Mohali - KL Rahul 30');

-- Workload Records (Training-based)
INSERT INTO Workload_Records (player_id, match_id, session_id, record_date, workload_score, source_type, notes) VALUES
(3, NULL, 1,  '2024-11-18', 145.00, 'Training', 'Bowling nets - pre Perth test'),
(4, NULL, 1,  '2024-11-18', 100.00, 'Training', 'Bowling nets - Jadeja left-arm'),
(8, NULL, 1,  '2024-11-18', 115.00, 'Training', 'Bowling nets - Pandya medium pace'),
(1, NULL, 2,  '2024-11-19', 90.00,  'Training', 'Batting nets - Rohit match sim'),
(2, NULL, 2,  '2024-11-19', 95.00,  'Training', 'Batting nets - Kohli match sim'),
(3, NULL, 5,  '2024-11-25', 125.00, 'Training', 'Adelaide bowling prep'),
(4, NULL, 6,  '2024-11-26', 85.00,  'Training', 'Adelaide batting spin prep'),
(1, NULL, 9,  '2025-02-07', 80.00,  'Training', 'T20 batting drills Kolkata'),
(7, NULL, 9,  '2025-02-07', 78.00,  'Training', 'T20 batting drills - SKY'),
(8, NULL, 10, '2025-02-08', 105.00, 'Training', 'Death bowling drills - Pandya'),
(9, NULL, 10, '2025-02-08', 98.00,  'Training', 'Death bowling drills - Axar');

INSERT INTO Injuries (player_id, injury_date, body_part, injury_type, severity, expected_recovery_days, actual_recovery_days, is_recovered, notes) VALUES
(6, '2023-11-15', 'Right Ankle',    'Ligament Tear',       'Severe',   90,  365, 0, 'Sustained during Ranji Trophy, prolonged recovery'),
(4, '2024-10-05', 'Lower Back',     'Muscle Strain',       'Moderate', 21,  18,  1, 'Resolved before Australia tour'),
(8, '2024-08-20', 'Right Ankle',    'Stress Fracture',     'Severe',   60,  75,  1, 'Recovered ahead of T20 WC'),
(3, '2024-09-10', 'Lower Back',     'Disc Inflammation',   'Moderate', 30,  28,  1, 'Managed with physio and rest'),
(10,'2024-11-01', 'Right Knee',     'Cartilage Damage',    'Severe',   120, NULL,0, 'Surgery done, rehab in progress'),
(1, '2025-01-10', 'Hamstring',      'Grade 1 Strain',      'Mild',     14,  12,  1, 'Occurred at MCG, minor'),
(2, '2024-07-15', 'Right Shoulder', 'Rotator Cuff Strain', 'Mild',     10,  10,  1, 'Resolved, full fitness');

INSERT INTO Recovery_Sessions (player_id, injury_id, session_date, recovery_type, duration_mins, pain_level, recovery_score, conducted_by) VALUES
(6,  1,    '2023-11-20', 'Physiotherapy', 60, 7, NULL, 'Dr. Nitin Patel'),
(6,  1,    '2023-12-05', 'Pool Session',  45, 5, NULL, 'Dr. Nitin Patel'),
(6,  1,    '2024-01-10', 'Gym Rehab',     60, 4, NULL, 'Soham Desai'),
(4,  2,    '2024-10-08', 'Physiotherapy', 45, 4, NULL, 'Team Physio'),
(4,  2,    '2024-10-15', 'Stretching',    30, 2, NULL, 'Team Physio'),
(8,  3,    '2024-08-25', 'Ice Bath',      20, 5, NULL, 'Team Physio'),
(8,  3,    '2024-09-01', 'Physiotherapy', 50, 4, NULL, 'Dr. Nitin Patel'),
(8,  3,    '2024-09-20', 'Gym Rehab',     60, 2, NULL, 'Soham Desai'),
(10, 5,    '2024-11-10', 'Physiotherapy', 60, 8, NULL, 'Dr. Nitin Patel'),
(10, 5,    '2024-11-25', 'Pool Session',  40, 6, NULL, 'Soham Desai'),
(10, 5,    '2024-12-15', 'Gym Rehab',     50, 5, NULL, 'Soham Desai'),
(1,  6,    '2025-01-11', 'Ice Bath',      20, 3, NULL, 'Team Physio'),
(1,  6,    '2025-01-14', 'Physiotherapy', 45, 2, NULL, 'Team Physio'),
(3,  NULL, '2024-12-07', 'Ice Bath',      20, 2, NULL, 'Team Physio'),
(3,  NULL, '2024-12-08', 'Rest',          30, 1, NULL, NULL),
(4,  NULL, '2024-12-07', 'Yoga',          40, 1, NULL, 'Team Physio');

INSERT INTO Workload_Alerts (player_id, alert_date, alert_type, alert_message, triggered_score, threshold_value, is_resolved) VALUES
(3, '2024-12-07', 'Overload',         'Bumrah workload score 310 exceeded threshold in Brisbane Test', 310.00, 250.00, 1),
(3, '2024-11-23', 'Consecutive Days', 'Bumrah bowled in 4 consecutive high-intensity sessions',        290.00, 250.00, 1),
(4, '2024-12-07', 'High Fatigue',     'Jadeja workload 255 - 3 consecutive high-load matches',         255.00, 240.00, 0),
(8, '2024-11-29', 'Spike Warning',    'Pandya workload spike after return from ankle injury',           200.00, 180.00, 1),
(6, '2023-11-16', 'Injury Risk',      'Shami ankle injury - removed from active roster',               0.00,   0.00,   0),
(10,'2024-11-02', 'Injury Risk',      'Iyer knee injury requires extended rest',                        0.00,   0.00,   0),
(1, '2025-01-11', 'Injury Risk',      'Rohit hamstring strain - day-to-day monitoring',                0.00,   0.00,   1),
(3, '2025-03-03', 'Overload',         'Bumrah MCG load 320 - critical zone',                           320.00, 250.00, 0);


-- ============================================================
-- SECTION 4: QUERIES (22)
-- ============================================================

-- Q1: All active players
SELECT player_id, full_name, role, jersey_number, ipl_team
FROM Players
WHERE status = 'Active'
ORDER BY full_name;

-- Q2: All Test matches played
SELECT match_id, match_date, opponent, venue, result
FROM Matches
WHERE format = 'Test'
ORDER BY match_date;

-- Q3: Training sessions with High or Very High intensity
SELECT session_id, session_date, session_type, duration_mins, intensity
FROM Training_Sessions
WHERE intensity IN ('High','Very High')
ORDER BY session_date;

-- Q4: All unresolved workload alerts
SELECT a.alert_id, p.full_name, a.alert_date, a.alert_type, a.alert_message
FROM Workload_Alerts a
JOIN Players p ON a.player_id = p.player_id
WHERE a.is_resolved = 0
ORDER BY a.alert_date DESC;

-- Q5: Players currently injured or resting
SELECT full_name, role, status
FROM Players
WHERE status IN ('Injured','Resting')
ORDER BY status;

-- Q6: Total workload score per player
SELECT p.full_name, p.role,
       ROUND(SUM(wr.workload_score),2)  AS total_workload,
       COUNT(wr.record_id)              AS total_sessions,
       ROUND(AVG(wr.workload_score),2)  AS avg_workload
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
GROUP BY p.player_id, p.full_name, p.role
ORDER BY total_workload DESC;

-- Q7: Match-day workload per player per match
SELECT m.match_date, m.opponent, m.format, p.full_name,
       wr.workload_score, wr.notes
FROM Workload_Records wr
JOIN Matches m  ON wr.match_id  = m.match_id
JOIN Players p  ON wr.player_id = p.player_id
ORDER BY m.match_date, wr.workload_score DESC;

-- Q8: Training workload per session with coach name
SELECT ts.session_date, ts.session_type, ts.intensity,
       c.full_name AS coach, p.full_name AS player,
       wr.workload_score, wr.notes
FROM Workload_Records wr
JOIN Training_Sessions ts ON wr.session_id = ts.session_id
JOIN Players p             ON wr.player_id  = p.player_id
JOIN Coaches c             ON ts.coach_id   = c.coach_id
ORDER BY ts.session_date, p.full_name;

-- Q9: Number of injuries per player with severity breakdown
SELECT p.full_name,
       COUNT(i.injury_id)                                      AS total_injuries,
       SUM(CASE WHEN i.severity='Mild'     THEN 1 ELSE 0 END) AS mild,
       SUM(CASE WHEN i.severity='Moderate' THEN 1 ELSE 0 END) AS moderate,
       SUM(CASE WHEN i.severity='Severe'   THEN 1 ELSE 0 END) AS severe,
       SUM(CASE WHEN i.is_recovered=0      THEN 1 ELSE 0 END) AS active_injuries
FROM Players p
JOIN Injuries i ON p.player_id = i.player_id
GROUP BY p.player_id, p.full_name
ORDER BY total_injuries DESC;

-- Q10: Recovery sessions per player with average pain level
SELECT p.full_name,
       COUNT(rs.recovery_id)       AS total_recovery_sessions,
       ROUND(AVG(rs.pain_level),1) AS avg_pain_level,
       SUM(rs.duration_mins)       AS total_recovery_mins
FROM Players p
JOIN Recovery_Sessions rs ON p.player_id = rs.player_id
GROUP BY p.player_id, p.full_name
ORDER BY total_recovery_sessions DESC;

-- Q11: Players with workload above team average (subquery)
SELECT p.full_name, p.role,
       ROUND(SUM(wr.workload_score),2) AS total_score
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
GROUP BY p.player_id, p.full_name, p.role
HAVING total_score > (
    SELECT AVG(sub.total)
    FROM (SELECT SUM(workload_score) AS total FROM Workload_Records GROUP BY player_id) sub
)
ORDER BY total_score DESC;

-- Q12: Won matches with number of players tracked
SELECT m.match_date, m.opponent, m.format, m.venue,
       COUNT(DISTINCT wr.player_id) AS players_tracked
FROM Matches m
JOIN Workload_Records wr ON m.match_id = wr.match_id
WHERE m.result = 'Won'
GROUP BY m.match_id, m.match_date, m.opponent, m.format, m.venue
ORDER BY m.match_date;

-- Q13: Coach with most high-intensity training sessions (HAVING)
SELECT c.full_name AS coach, c.specialization,
       COUNT(ts.session_id) AS high_intensity_sessions
FROM Coaches c
JOIN Training_Sessions ts ON c.coach_id = ts.coach_id
WHERE ts.intensity IN ('High','Very High')
GROUP BY c.coach_id, c.full_name, c.specialization
HAVING high_intensity_sessions >= 2
ORDER BY high_intensity_sessions DESC;

-- Q14: Highest workload players (top 5)
SELECT p.full_name, p.role, p.status,
       ROUND(SUM(wr.workload_score),2) AS total_workload,
       COUNT(wr.record_id)             AS appearances
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
GROUP BY p.player_id, p.full_name, p.role, p.status
ORDER BY total_workload DESC
LIMIT 5;

-- Q15: Injury risk players (active + high workload or active injury)
SELECT p.full_name, p.role,
       ROUND(SUM(wr.workload_score),2) AS total_workload,
       COUNT(DISTINCT i.injury_id)     AS active_injury_count
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
LEFT JOIN Injuries i      ON p.player_id = i.player_id AND i.is_recovered = 0
WHERE p.status = 'Active'
GROUP BY p.player_id, p.full_name, p.role
HAVING total_workload > 200 OR active_injury_count > 0
ORDER BY total_workload DESC;

-- Q16: Overworked bowlers (workload > 300 total)
SELECT p.full_name, p.role,
       ROUND(SUM(wr.workload_score),2) AS total_workload,
       COUNT(wr.record_id)             AS sessions_played,
       ROUND(AVG(wr.workload_score),1) AS avg_per_session
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
WHERE p.role IN ('Bowler','All-Rounder')
GROUP BY p.player_id, p.full_name, p.role
HAVING total_workload > 300
ORDER BY total_workload DESC;

-- Q17: Match vs Training workload comparison per player
SELECT p.full_name,
       ROUND(SUM(CASE WHEN wr.source_type='Match'    THEN wr.workload_score ELSE 0 END),2) AS match_workload,
       ROUND(SUM(CASE WHEN wr.source_type='Training' THEN wr.workload_score ELSE 0 END),2) AS training_workload,
       ROUND(SUM(wr.workload_score),2)                                                       AS total_workload
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
GROUP BY p.player_id, p.full_name
ORDER BY total_workload DESC;

-- Q18: Team workload summary by format
SELECT m.format,
       COUNT(DISTINCT m.match_id)      AS matches_played,
       COUNT(DISTINCT wr.player_id)    AS players_involved,
       ROUND(SUM(wr.workload_score),2) AS total_team_workload,
       ROUND(AVG(wr.workload_score),2) AS avg_per_record
FROM Matches m
JOIN Workload_Records wr ON m.match_id = wr.match_id
GROUP BY m.format
ORDER BY total_team_workload DESC;

-- Q19: Injury history report with recovery duration
SELECT p.full_name, i.injury_date, i.body_part, i.injury_type, i.severity,
       i.expected_recovery_days, i.actual_recovery_days,
       CASE WHEN i.is_recovered=1 THEN 'Recovered' ELSE 'Active' END AS recovery_status,
       DATEDIFF(CURDATE(), i.injury_date) AS days_since_injury
FROM Injuries i
JOIN Players p ON i.player_id = p.player_id
ORDER BY i.injury_date DESC;

-- Q20: Monthly workload trend per player
SELECT p.full_name,
       DATE_FORMAT(wr.record_date,'%Y-%m') AS month,
       ROUND(SUM(wr.workload_score),2)     AS monthly_workload,
       COUNT(wr.record_id)                 AS sessions
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
GROUP BY p.player_id, p.full_name, month
ORDER BY p.full_name, month;

-- Q21: View – Player workload summary
CREATE OR REPLACE VIEW vw_player_workload_summary AS
SELECT p.player_id, p.full_name, p.role, p.status,
       COUNT(wr.record_id)                     AS total_records,
       ROUND(SUM(wr.workload_score),2)         AS total_workload,
       ROUND(AVG(wr.workload_score),2)         AS avg_workload,
       SUM(CASE WHEN wr.source_type='Match'    THEN wr.workload_score ELSE 0 END) AS match_workload,
       SUM(CASE WHEN wr.source_type='Training' THEN wr.workload_score ELSE 0 END) AS training_workload,
       COUNT(DISTINCT i.injury_id)             AS total_injuries
FROM Players p
LEFT JOIN Workload_Records wr ON p.player_id = wr.player_id
LEFT JOIN Injuries i           ON p.player_id = i.player_id
GROUP BY p.player_id, p.full_name, p.role, p.status;

-- Q22: View – Unresolved alerts with player info
CREATE OR REPLACE VIEW vw_active_alerts AS
SELECT wa.alert_id, p.full_name, p.role, p.status,
       wa.alert_date, wa.alert_type, wa.alert_message,
       wa.triggered_score, wa.threshold_value
FROM Workload_Alerts wa
JOIN Players p ON wa.player_id = p.player_id
WHERE wa.is_resolved = 0
ORDER BY wa.alert_date DESC;


-- ============================================================
-- SECTION 5: STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- SP1: Add a workload record for a match
CREATE PROCEDURE sp_add_match_workload(
    IN p_player_id     INT,
    IN p_match_id      INT,
    IN p_record_date   DATE,
    IN p_workload_score DECIMAL(6,2),
    IN p_notes         VARCHAR(255)
)
BEGIN
    INSERT INTO Workload_Records
        (player_id, match_id, session_id, record_date, workload_score, source_type, notes)
    VALUES
        (p_player_id, p_match_id, NULL, p_record_date, p_workload_score, 'Match', p_notes);
    SELECT LAST_INSERT_ID() AS new_record_id;
END$$

-- SP2: Weekly workload report for a player
CREATE PROCEDURE sp_weekly_workload_report(
    IN p_player_id  INT,
    IN p_week_start DATE
)
BEGIN
    DECLARE v_week_end DATE;
    SET v_week_end = DATE_ADD(p_week_start, INTERVAL 6 DAY);

    SELECT wr.record_id, wr.record_date, wr.source_type,
           COALESCE(m.opponent, ts.session_type) AS detail,
           wr.workload_score, wr.notes
    FROM Workload_Records wr
    LEFT JOIN Matches m            ON wr.match_id   = m.match_id
    LEFT JOIN Training_Sessions ts ON wr.session_id = ts.session_id
    WHERE wr.player_id   = p_player_id
      AND wr.record_date BETWEEN p_week_start AND v_week_end
    ORDER BY wr.record_date;

    SELECT ROUND(SUM(workload_score),2) AS weekly_total,
           ROUND(AVG(workload_score),2) AS weekly_avg,
           COUNT(record_id)             AS sessions_count
    FROM Workload_Records
    WHERE player_id   = p_player_id
      AND record_date BETWEEN p_week_start AND v_week_end;
END$$

-- SP3: Player injury report
CREATE PROCEDURE sp_player_injury_report(IN p_player_id INT)
BEGIN
    SELECT p.full_name, p.role, p.status,
           i.injury_date, i.body_part, i.injury_type, i.severity,
           i.expected_recovery_days, i.actual_recovery_days,
           IF(i.is_recovered, 'Recovered', 'Ongoing') AS recovery_status
    FROM Injuries i
    JOIN Players p ON i.player_id = p.player_id
    WHERE i.player_id = p_player_id
    ORDER BY i.injury_date DESC;

    SELECT COUNT(*)                          AS total_injuries,
           SUM(IF(is_recovered=1,1,0))       AS recovered,
           SUM(IF(is_recovered=0,1,0))       AS ongoing
    FROM Injuries
    WHERE player_id = p_player_id;
END$$

-- SP4: High risk player report
CREATE PROCEDURE sp_high_risk_players(IN p_threshold DECIMAL(6,2))
BEGIN
    SELECT p.player_id, p.full_name, p.role, p.status,
           ROUND(SUM(wr.workload_score),2)  AS total_workload,
           ROUND(AVG(wr.workload_score),2)  AS avg_workload,
           COUNT(DISTINCT i.injury_id)      AS active_injuries,
           COUNT(DISTINCT wa.alert_id)      AS unresolved_alerts
    FROM Players p
    JOIN Workload_Records wr     ON p.player_id = wr.player_id
    LEFT JOIN Injuries i         ON p.player_id = i.player_id AND i.is_recovered = 0
    LEFT JOIN Workload_Alerts wa ON p.player_id = wa.player_id AND wa.is_resolved = 0
    GROUP BY p.player_id, p.full_name, p.role, p.status
    HAVING total_workload > p_threshold
    ORDER BY total_workload DESC;
END$$

-- SP5: Team workload summary by format
CREATE PROCEDURE sp_team_workload_summary()
BEGIN
    SELECT m.format,
           COUNT(DISTINCT m.match_id)      AS matches,
           COUNT(DISTINCT wr.player_id)    AS players,
           ROUND(SUM(wr.workload_score),2) AS total_workload,
           ROUND(AVG(wr.workload_score),2) AS avg_per_record
    FROM Workload_Records wr
    JOIN Matches m ON wr.match_id = m.match_id
    GROUP BY m.format
    ORDER BY total_workload DESC;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 6: FUNCTIONS
-- ============================================================

DELIMITER $$

-- FN1: Calculate workload score from a numeric load value and intensity multiplier
-- Used when inserting records manually; triggers call this automatically.
-- Parameters: base_load (e.g. duration or balls), intensity_factor (1.0–2.0), bonus (runs/extras)
CREATE FUNCTION fn_calculate_workload_score(
    p_base_load       DECIMAL(8,2),
    p_intensity_factor DECIMAL(4,2),
    p_bonus           DECIMAL(6,2),
    p_rpe             TINYINT
) RETURNS DECIMAL(6,2)
DETERMINISTIC
BEGIN
    DECLARE v_score DECIMAL(6,2);
    SET v_score = (p_base_load * p_intensity_factor)
                + p_bonus
                + (COALESCE(p_rpe, 5) * 4.0);
    IF v_score < 0 THEN SET v_score = 0; END IF;
    RETURN ROUND(v_score, 2);
END$$

-- FN2: Fatigue index
CREATE FUNCTION fn_fatigue_index(
    p_total_workload DECIMAL(8,2),
    p_avg_workload   DECIMAL(8,2),
    p_sessions       INT
) RETURNS DECIMAL(8,2)
DETERMINISTIC
BEGIN
    DECLARE v_index DECIMAL(8,2);
    IF p_sessions = 0 THEN RETURN 0.00; END IF;
    SET v_index = (p_total_workload / p_sessions) * (p_avg_workload / 100.0);
    RETURN ROUND(v_index, 2);
END$$

-- FN3: Acute:Chronic Workload Ratio (ACWR)
-- Acute = last 7 days load; Chronic = 28-day average weekly load
CREATE FUNCTION fn_acwr(p_player_id INT) RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_acute   DECIMAL(8,2) DEFAULT 0;
    DECLARE v_chronic DECIMAL(8,2) DEFAULT 0;

    SELECT COALESCE(SUM(workload_score), 0)
    INTO v_acute
    FROM Workload_Records
    WHERE player_id = p_player_id
      AND record_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);

    SELECT COALESCE(SUM(workload_score) / 4.0, 0)
    INTO v_chronic
    FROM Workload_Records
    WHERE player_id = p_player_id
      AND record_date >= DATE_SUB(CURDATE(), INTERVAL 28 DAY);

    IF v_chronic = 0 THEN RETURN 0.00; END IF;
    RETURN ROUND(v_acute / v_chronic, 2);
END$$

-- FN4: Recovery score (higher duration + lower pain = better score)
CREATE FUNCTION fn_recovery_score(
    p_duration_mins SMALLINT,
    p_pain_level    TINYINT
) RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE v_score DECIMAL(5,2);
    SET v_score = (p_duration_mins * 0.5) - (COALESCE(p_pain_level, 5) * 3.0);
    IF v_score < 0 THEN SET v_score = 0; END IF;
    RETURN ROUND(v_score, 2);
END$$

-- FN5: Risk classification based on total workload score
CREATE FUNCTION fn_risk_class(p_workload DECIMAL(6,2)) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_class VARCHAR(20);
    IF    p_workload < 100 THEN SET v_class = 'Low';
    ELSEIF p_workload < 200 THEN SET v_class = 'Moderate';
    ELSEIF p_workload < 300 THEN SET v_class = 'High';
    ELSE                         SET v_class = 'Critical';
    END IF;
    RETURN v_class;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 7: TRIGGERS
-- ============================================================

DELIMITER $$

-- TR1: Enforce source consistency (replaces chk_wr_source CHECK constraint)
-- MySQL Error 3823: FK columns cannot appear inside CHECK constraints; use a BEFORE INSERT trigger instead.
CREATE TRIGGER trg_wr_source_check
BEFORE INSERT ON Workload_Records
FOR EACH ROW
BEGIN
    IF NOT (
        (NEW.match_id IS NOT NULL AND NEW.session_id IS NULL AND NEW.source_type = 'Match') OR
        (NEW.session_id IS NOT NULL AND NEW.match_id IS NULL AND NEW.source_type = 'Training')
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid source: exactly one of match_id/session_id must be set and must match source_type.';
    END IF;
END$$

-- TR2: Generate alert automatically when workload_score > 250 on INSERT
CREATE TRIGGER trg_wr_alert_on_insert
AFTER INSERT ON Workload_Records
FOR EACH ROW
BEGIN
    IF NEW.workload_score > 250 THEN
        INSERT INTO Workload_Alerts
            (player_id, alert_date, alert_type, alert_message, triggered_score, threshold_value)
        VALUES
            (NEW.player_id, NEW.record_date, 'Overload',
             CONCAT('Auto-alert: workload score ', NEW.workload_score, ' exceeded threshold 250'),
             NEW.workload_score, 250.00);
    END IF;
END$$

-- TR3: Generate alert automatically when workload_score > 250 on UPDATE
CREATE TRIGGER trg_wr_alert_on_update
AFTER UPDATE ON Workload_Records
FOR EACH ROW
BEGIN
    IF NEW.workload_score > 250 AND OLD.workload_score <= 250 THEN
        INSERT INTO Workload_Alerts
            (player_id, alert_date, alert_type, alert_message, triggered_score, threshold_value)
        VALUES
            (NEW.player_id, NEW.record_date, 'Overload',
             CONCAT('Auto-alert: updated workload score ', NEW.workload_score, ' exceeded threshold 250'),
             NEW.workload_score, 250.00);
    END IF;
END$$

-- TR4: Update player status to 'Injured' when a new injury record is inserted
CREATE TRIGGER trg_injury_update_player_status
AFTER INSERT ON Injuries
FOR EACH ROW
BEGIN
    UPDATE Players
    SET status = 'Injured'
    WHERE player_id = NEW.player_id;
END$$

-- TR5: Restore player status to 'Active' when injury is marked as recovered
CREATE TRIGGER trg_injury_mark_recovered
AFTER UPDATE ON Injuries
FOR EACH ROW
BEGIN
    IF NEW.is_recovered = 1 AND OLD.is_recovered = 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM Injuries
            WHERE player_id = NEW.player_id AND is_recovered = 0 AND injury_id <> NEW.injury_id
        ) THEN
            UPDATE Players SET status = 'Active' WHERE player_id = NEW.player_id;
        END IF;
    END IF;
END$$

-- TR6: Prevent adding a workload record for an injured player
CREATE TRIGGER trg_prevent_injured_player_workload
BEFORE INSERT ON Workload_Records
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);
    SELECT status INTO v_status FROM Players WHERE player_id = NEW.player_id;
    IF v_status = 'Injured' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot add workload record: player is currently injured.';
    END IF;
END$$

DELIMITER ;

-- Update recovery scores using the function
-- Disable safe update mode temporarily (Error 1175: UPDATE without WHERE on primary key)
SET SQL_SAFE_UPDATES = 0;
UPDATE Recovery_Sessions
SET recovery_score = fn_recovery_score(duration_mins, pain_level)
WHERE recovery_id > 0;
SET SQL_SAFE_UPDATES = 1;


-- ============================================================
-- SECTION 8: CURSORS
-- ============================================================

DELIMITER $$

-- CURSOR 1: Generate workload report for all active players
CREATE PROCEDURE sp_cursor_active_player_report()
BEGIN
    DECLARE v_done        INT DEFAULT 0;
    DECLARE v_player_id   INT;
    DECLARE v_player_name VARCHAR(100);
    DECLARE v_role        VARCHAR(30);
    DECLARE v_total_wl    DECIMAL(8,2);
    DECLARE v_avg_wl      DECIMAL(8,2);

    DECLARE cur_players CURSOR FOR
        SELECT p.player_id, p.full_name, p.role,
               COALESCE(SUM(wr.workload_score), 0) AS total_wl,
               COALESCE(AVG(wr.workload_score), 0) AS avg_wl
        FROM Players p
        LEFT JOIN Workload_Records wr ON p.player_id = wr.player_id
        WHERE p.status = 'Active'
        GROUP BY p.player_id, p.full_name, p.role;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_player_report (
        player_name VARCHAR(100),
        role        VARCHAR(30),
        total_load  DECIMAL(8,2),
        avg_load    DECIMAL(8,2),
        risk_class  VARCHAR(20)
    );
    TRUNCATE TABLE tmp_player_report;

    OPEN cur_players;
    read_loop: LOOP
        FETCH cur_players INTO v_player_id, v_player_name, v_role, v_total_wl, v_avg_wl;
        IF v_done THEN LEAVE read_loop; END IF;
        INSERT INTO tmp_player_report VALUES (
            v_player_name, v_role, v_total_wl, v_avg_wl, fn_risk_class(v_total_wl)
        );
    END LOOP;
    CLOSE cur_players;

    SELECT * FROM tmp_player_report ORDER BY total_load DESC;
    DROP TEMPORARY TABLE tmp_player_report;
END$$

-- CURSOR 2: Bulk update recovery scores for all recovery sessions
CREATE PROCEDURE sp_cursor_update_recovery_scores()
BEGIN
    DECLARE v_done   INT DEFAULT 0;
    DECLARE v_rec_id INT;
    DECLARE v_dur    SMALLINT;
    DECLARE v_pain   TINYINT;

    DECLARE cur_recovery CURSOR FOR
        SELECT recovery_id, duration_mins, pain_level FROM Recovery_Sessions;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_recovery;
    upd_loop: LOOP
        FETCH cur_recovery INTO v_rec_id, v_dur, v_pain;
        IF v_done THEN LEAVE upd_loop; END IF;
        UPDATE Recovery_Sessions
        SET recovery_score = fn_recovery_score(v_dur, COALESCE(v_pain, 5))
        WHERE recovery_id = v_rec_id;
    END LOOP;
    CLOSE cur_recovery;

    SELECT 'Recovery scores updated successfully.' AS result;
END$$

-- CURSOR 3: Role-based workload summary with ACWR
CREATE PROCEDURE sp_cursor_role_workload_summary()
BEGIN
    DECLARE v_done  INT DEFAULT 0;
    DECLARE v_pid   INT;
    DECLARE v_name  VARCHAR(100);
    DECLARE v_role  VARCHAR(30);
    DECLARE v_wl    DECIMAL(8,2);
    DECLARE v_acwr  DECIMAL(5,2);

    DECLARE cur_all CURSOR FOR
        SELECT p.player_id, p.full_name, p.role,
               COALESCE(SUM(wr.workload_score), 0) AS wl
        FROM Players p
        LEFT JOIN Workload_Records wr ON p.player_id = wr.player_id
        GROUP BY p.player_id, p.full_name, p.role
        ORDER BY p.role;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_role_summary (
        player_name VARCHAR(100),
        role        VARCHAR(30),
        total_wl    DECIMAL(8,2),
        acwr        DECIMAL(5,2),
        risk        VARCHAR(20)
    );
    TRUNCATE TABLE tmp_role_summary;

    OPEN cur_all;
    role_loop: LOOP
        FETCH cur_all INTO v_pid, v_name, v_role, v_wl;
        IF v_done THEN LEAVE role_loop; END IF;
        SET v_acwr = fn_acwr(v_pid);
        INSERT INTO tmp_role_summary VALUES (v_name, v_role, v_wl, v_acwr, fn_risk_class(v_wl));
    END LOOP;
    CLOSE cur_all;

    SELECT * FROM tmp_role_summary ORDER BY role, total_wl DESC;
    DROP TEMPORARY TABLE tmp_role_summary;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 9: TRANSACTIONS
-- ============================================================

-- TRANSACTION 1: Record injury and update player status atomically
START TRANSACTION;
SAVEPOINT sp_before_injury;

INSERT INTO Injuries
    (player_id, injury_date, body_part, injury_type, severity, expected_recovery_days, is_recovered)
VALUES
    (9, CURDATE(), 'Left Hamstring', 'Grade 2 Tear', 'Moderate', 28, 0);

-- TR3 trigger fires here and sets Axar's status to 'Injured' automatically

INSERT INTO Workload_Alerts
    (player_id, alert_date, alert_type, alert_message, triggered_score, threshold_value)
VALUES
    (9, CURDATE(), 'Injury Risk',
     'Axar Patel sustained hamstring tear - removed from active roster', 0.00, 0.00);

COMMIT;


-- TRANSACTION 2: Workload insert with ROLLBACK demo then corrected insert
START TRANSACTION;
SAVEPOINT sp_before_workload;

INSERT INTO Workload_Records
    (player_id, match_id, session_id, record_date, workload_score, source_type, notes)
VALUES
    (2, 10, NULL, '2025-03-05', 350.00, 'Match', 'Erroneous high score - will rollback');

-- Business rule: score above 350 needs manual review — rollback
ROLLBACK TO SAVEPOINT sp_before_workload;

-- Insert corrected value
INSERT INTO Workload_Records
    (player_id, match_id, session_id, record_date, workload_score, source_type, notes)
VALUES
    (2, 10, NULL, '2025-03-05', 225.00, 'Match', 'ODI Jaipur - Kohli 101 match-winner');

COMMIT;


-- TRANSACTION 3: Multi-table recovery session registration
START TRANSACTION;
SAVEPOINT sp_rs_start;

INSERT INTO Recovery_Sessions
    (player_id, injury_id, session_date, recovery_type, duration_mins, pain_level, conducted_by)
VALUES
    (9, NULL, CURDATE(), 'Physiotherapy', 45, 6, 'Dr. Nitin Patel');

UPDATE Injuries
SET notes = CONCAT(COALESCE(notes,''), ' | Physio started on ', CURDATE())
WHERE player_id = 9 AND is_recovered = 0
ORDER BY injury_date DESC
LIMIT 1;

COMMIT;


-- ============================================================
-- SECTION 10: OPTIMIZATION
-- ============================================================

EXPLAIN SELECT p.full_name, ROUND(SUM(wr.workload_score),2) AS total
FROM Players p
JOIN Workload_Records wr ON p.player_id = wr.player_id
WHERE wr.record_date >= '2024-11-01'
GROUP BY p.player_id, p.full_name
ORDER BY total DESC;

-- Reporting via views
SELECT * FROM vw_player_workload_summary ORDER BY total_workload DESC;
SELECT * FROM vw_active_alerts;

-- Stored procedure calls
CALL sp_team_workload_summary();
CALL sp_high_risk_players(200);
CALL sp_weekly_workload_report(3, '2024-11-18');
CALL sp_player_injury_report(3);
CALL sp_cursor_active_player_report();
CALL sp_cursor_update_recovery_scores();
CALL sp_cursor_role_workload_summary();

-- Function tests
SELECT fn_calculate_workload_score(120.0, 1.8, 20.0, 9) AS sample_workload_score;
SELECT fn_fatigue_index(1200.00, 240.00, 6)              AS fatigue_index_sample;
SELECT fn_acwr(3)                                        AS bumrah_acwr;
SELECT fn_recovery_score(60, 4)                          AS recovery_score_sample;
SELECT fn_risk_class(310)                                AS risk_classification;

-- ============================================================
-- END OF PROJECT
-- ============================================================
