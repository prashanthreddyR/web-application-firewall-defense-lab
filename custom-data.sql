-- Extra data to target during SQL injection demos (section 4.5)
-- Run AFTER DVWA's setup.php has created the dvwa database:
--   sudo mysql -u root -p < sql/custom-data.sql
USE dvwa;

CREATE TABLE IF NOT EXISTS test_users (
  id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  password VARCHAR(50) NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO test_users (username, password) VALUES
  ('alice', 'alice123'),
  ('bob',   'bob123'),
  ('admin', 'admin123');
