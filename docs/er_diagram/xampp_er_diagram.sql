-- docs/er_diagram/xampp_er_diagram.sql
-- Purpose : A MySQL/MariaDB copy of the 14 TripGraph tables (columns, primary keys, foreign keys)
--           used ONLY to draw the diagram in XAMPP (phpMyAdmin > Designer).
--           The real project database is PostgreSQL (schema/01 to 04). Triggers, views,
--           functions and sample data are NOT part of this file.
-- How to run: XAMPP Control Panel -> start Apache and MySQL -> open http://localhost/phpmyadmin
--             -> Import tab -> choose this file -> Go.  (It creates the database tripgraph_diagram.)

DROP DATABASE IF EXISTS tripgraph_diagram;
CREATE DATABASE tripgraph_diagram CHARACTER SET utf8mb4;
USE tripgraph_diagram;

CREATE TABLE app_user (
  user_id    INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(150) NOT NULL UNIQUE,
  role       VARCHAR(10)  NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE category (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  group_name  VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE node (
  node_id INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(100) NOT NULL UNIQUE,
  kind    VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE edge (
  edge_id    INT AUTO_INCREMENT PRIMARY KEY,
  from_node  INT           NOT NULL,
  to_node    INT           NOT NULL,
  mode       VARCHAR(30)   NOT NULL,
  distance_m INT           NOT NULL,
  time_min   INT           NOT NULL,
  fare       DECIMAL(6,2)  NOT NULL DEFAULT 0 CHECK (fare >= 0),
  FOREIGN KEY (from_node) REFERENCES node (node_id),
  FOREIGN KEY (to_node)   REFERENCES node (node_id)
) ENGINE=InnoDB;

CREATE TABLE place (
  place_id         INT AUTO_INCREMENT PRIMARY KEY,
  name             VARCHAR(150)  NOT NULL,
  category_id      INT           NOT NULL,
  address          VARCHAR(255),
  lat              DECIMAL(9,6)  NOT NULL,
  lon              DECIMAL(9,6)  NOT NULL,
  price_level      SMALLINT      NOT NULL CHECK (price_level BETWEEN 1 AND 3),
  student_discount BOOLEAN       NOT NULL DEFAULT FALSE,
  avg_rating       DECIMAL(3,2)  NOT NULL DEFAULT 0,
  review_count     INT           NOT NULL DEFAULT 0,
  node_id          INT           NOT NULL,
  FOREIGN KEY (category_id) REFERENCES category (category_id),
  FOREIGN KEY (node_id)     REFERENCES node (node_id)
) ENGINE=InnoDB;

CREATE TABLE food_outlet (
  place_id INT PRIMARY KEY,
  cuisine  VARCHAR(100),
  is_veg   BOOLEAN NOT NULL,
  FOREIGN KEY (place_id) REFERENCES place (place_id)
) ENGINE=InnoDB;

CREATE TABLE tag (
  tag_id INT AUTO_INCREMENT PRIMARY KEY,
  name   VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE place_tag (
  place_id INT NOT NULL,
  tag_id   INT NOT NULL,
  PRIMARY KEY (place_id, tag_id),
  FOREIGN KEY (place_id) REFERENCES place (place_id),
  FOREIGN KEY (tag_id)   REFERENCES tag (tag_id)
) ENGINE=InnoDB;

-- Weak entity of place. day is ISO: 1 = Monday ... 7 = Sunday.
CREATE TABLE opening_hours (
  place_id   INT      NOT NULL,
  day        SMALLINT NOT NULL CHECK (day BETWEEN 1 AND 7),
  open_time  TIME     NOT NULL,
  close_time TIME     NOT NULL,
  PRIMARY KEY (place_id, day),
  FOREIGN KEY (place_id) REFERENCES place (place_id)
) ENGINE=InnoDB;

CREATE TABLE review (
  user_id     INT      NOT NULL,
  place_id    INT      NOT NULL,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, place_id),
  FOREIGN KEY (user_id)  REFERENCES app_user (user_id),
  FOREIGN KEY (place_id) REFERENCES place (place_id)
) ENGINE=InnoDB;

CREATE TABLE favorite (
  user_id  INT      NOT NULL,
  place_id INT      NOT NULL,
  visited  BOOLEAN  NOT NULL DEFAULT FALSE,
  saved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, place_id),
  FOREIGN KEY (user_id)  REFERENCES app_user (user_id),
  FOREIGN KEY (place_id) REFERENCES place (place_id)
) ENGINE=InnoDB;

CREATE TABLE trip (
  trip_id    INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT      NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES app_user (user_id)
) ENGINE=InnoDB;

-- Weak entity of trip.
CREATE TABLE trip_leg (
  trip_id INT      NOT NULL,
  leg_no  SMALLINT NOT NULL,
  edge_id INT      NOT NULL,
  PRIMARY KEY (trip_id, leg_no),
  FOREIGN KEY (trip_id) REFERENCES trip (trip_id),
  FOREIGN KEY (edge_id) REFERENCES edge (edge_id)
) ENGINE=InnoDB;

-- Standalone log table: no foreign keys.
CREATE TABLE audit_log (
  log_id     INT AUTO_INCREMENT PRIMARY KEY,
  action     VARCHAR(50)  NOT NULL,
  table_name VARCHAR(50)  NOT NULL,
  record_id  VARCHAR(50),
  logged_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
