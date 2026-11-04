-- VPrime Patient Feedback & Review Monitoring Portal
-- MySQL 5.7+/8, utf8mb4, InnoDB
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE branches (
  id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(80) NOT NULL,
  google_review_url VARCHAR(500) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE admin_users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('super_admin','branch_admin','compliance_executive') NOT NULL,
  branch_id TINYINT UNSIGNED NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  failed_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until DATETIME NULL,
  last_login_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_branch FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_resets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_reset_token (token_hash),
  CONSTRAINT fk_reset_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE therapists (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_id TINYINT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_therapist (branch_id, name),
  CONSTRAINT fk_ther_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional clinic master list (CSV import) used for Patient ID / therapist verification
CREATE TABLE patient_records (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id VARCHAR(40) NOT NULL,
  branch_id TINYINT UNSIGNED NOT NULL,
  assigned_therapist_id INT UNSIGNED NULL,
  last_visit_date DATE NULL,
  imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_patient_branch (patient_id, branch_id),
  CONSTRAINT fk_pr_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
  CONSTRAINT fk_pr_ther FOREIGN KEY (assigned_therapist_id) REFERENCES therapists(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE feedback (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  submission_uid CHAR(32) NOT NULL UNIQUE,
  patient_id VARCHAR(40) NOT NULL,
  patient_name VARCHAR(100) NULL,
  branch_id TINYINT UNSIGNED NOT NULL,
  treatment_date DATE NOT NULL,
  reported_therapist_id INT UNSIGNED NULL,
  overall_rating TINYINT UNSIGNED NOT NULL,
  treatment_satisfaction TINYINT UNSIGNED NOT NULL,
  comments TEXT NULL,
  is_complaint TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_fb_patient (patient_id, created_at),
  INDEX idx_fb_branch_date (branch_id, created_at),
  INDEX idx_fb_ther (reported_therapist_id),
  CONSTRAINT chk_rating CHECK (overall_rating BETWEEN 1 AND 5),
  CONSTRAINT chk_sat CHECK (treatment_satisfaction BETWEEN 1 AND 5),
  CONSTRAINT fk_fb_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
  CONSTRAINT fk_fb_ther FOREIGN KEY (reported_therapist_id) REFERENCES therapists(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE submission_activity (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  feedback_id INT UNSIGNED NOT NULL UNIQUE,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(255) NULL,
  device_category ENUM('mobile','tablet','desktop','unknown') NOT NULL DEFAULT 'unknown',
  session_hash CHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_act_ip (ip_address, created_at),
  INDEX idx_act_session (session_hash, created_at),
  CONSTRAINT fk_act_fb FOREIGN KEY (feedback_id) REFERENCES feedback(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE duplicate_flags (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  feedback_id INT UNSIGNED NOT NULL,
  flag_type ENUM('repeat_patient','shared_ip_burst','repeat_session','patient_not_in_records','therapist_mismatch','cross_branch','unusual_pattern') NOT NULL,
  reason VARCHAR(500) NOT NULL,
  related_feedback_ids VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_flag_type (flag_type),
  INDEX idx_flag_fb (feedback_id),
  CONSTRAINT fk_flag_fb FOREIGN KEY (feedback_id) REFERENCES feedback(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE compliance_investigations (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  flag_id INT UNSIGNED NOT NULL UNIQUE,
  branch_id TINYINT UNSIGNED NOT NULL,
  patient_id VARCHAR(40) NOT NULL,
  assigned_therapist_id INT UNSIGNED NULL,
  status ENUM('new','pending_verification','verified','suspicious','escalated','closed') NOT NULL DEFAULT 'new',
  remarks TEXT NULL,
  admin_id INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_inv_status (status),
  INDEX idx_inv_branch (branch_id, status),
  CONSTRAINT fk_inv_flag FOREIGN KEY (flag_id) REFERENCES duplicate_flags(id) ON DELETE CASCADE,
  CONSTRAINT fk_inv_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
  CONSTRAINT fk_inv_ther FOREIGN KEY (assigned_therapist_id) REFERENCES therapists(id) ON DELETE SET NULL,
  CONSTRAINT fk_inv_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE investigation_notes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  investigation_id INT UNSIGNED NOT NULL,
  admin_id INT UNSIGNED NULL,
  old_status VARCHAR(30) NULL,
  new_status VARCHAR(30) NULL,
  note TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_note_inv FOREIGN KEY (investigation_id) REFERENCES compliance_investigations(id) ON DELETE CASCADE,
  CONSTRAINT fk_note_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Records only that the OPTIONAL link was clicked, never that a review was posted
CREATE TABLE review_link_clicks (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  feedback_id INT UNSIGNED NULL,
  branch_id TINYINT UNSIGNED NOT NULL,
  clicked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_click_branch (branch_id, clicked_at),
  CONSTRAINT fk_click_fb FOREIGN KEY (feedback_id) REFERENCES feedback(id) ON DELETE SET NULL,
  CONSTRAINT fk_click_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE admin_activity_logs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  details VARCHAR(500) NULL,
  ip_address VARCHAR(45) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_log_admin (admin_id, created_at),
  CONSTRAINT fk_log_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE system_settings (
  setting_key VARCHAR(60) PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  description VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Correction / deletion requests (DPDP Act)
CREATE TABLE data_requests (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  request_type ENUM('correction','deletion') NOT NULL,
  patient_id VARCHAR(40) NOT NULL,
  contact VARCHAR(150) NULL,
  details TEXT NULL,
  status ENUM('open','in_progress','completed','rejected') NOT NULL DEFAULT 'open',
  handled_by INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_dr_admin FOREIGN KEY (handled_by) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- Seed data ------------------------------------------------------------
INSERT INTO branches (code, name, google_review_url) VALUES
 ('ANNA_NAGAR','Anna Nagar','https://REPLACE-WITH-ANNA-NAGAR-GOOGLE-REVIEW-LINK'),
 ('VELACHERY','Velachery','https://REPLACE-WITH-VELACHERY-GOOGLE-REVIEW-LINK'),
 ('ASHOK_NAGAR','Ashok Nagar','https://REPLACE-WITH-ASHOK-NAGAR-GOOGLE-REVIEW-LINK');

INSERT INTO system_settings (setting_key, setting_value, description) VALUES
 ('dup_patient_window_hours','24','Window for repeat submissions by same Patient ID'),
 ('dup_patient_max','1','Submissions allowed per Patient ID in window before flagging'),
 ('dup_ip_window_minutes','30','Window for shared-IP burst check'),
 ('dup_ip_max','5','Submissions from one IP in window before flagging (shared clinic/Wi-Fi IPs are only a lead)'),
 ('dup_session_window_minutes','60','Window for repeat browser-session check'),
 ('dup_session_max','2','Submissions per session in window before flagging'),
 ('unusual_burst_window_minutes','60','Window for branch-wide burst check'),
 ('unusual_burst_max','15','Branch submissions in window before flagging'),
 ('retention_technical_days','90','Days to keep IP/user-agent data before purge'),
 ('retention_feedback_days','730','Days to keep feedback records'),
 ('session_timeout_minutes','20','Admin idle timeout'),
 ('max_login_attempts','5','Failed logins before lockout'),
 ('lockout_minutes','15','Lockout duration'),
 ('privacy_contact_email','privacy@example.com','Contact shown on privacy notice');
