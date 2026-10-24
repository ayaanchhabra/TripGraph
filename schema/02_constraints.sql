-- schema/02_constraints.sql   (K)
-- UNIQUE, CHECK and FOREIGN KEY rules. Run after 01_tables.sql.

\set ON_ERROR_STOP on

-- ---------- UNIQUE ----------
-- A's loaders look things up by name, so names must be unique.
ALTER TABLE app_user ADD CONSTRAINT uq_user_email    UNIQUE (email);
ALTER TABLE category ADD CONSTRAINT uq_category_name UNIQUE (name);
ALTER TABLE node     ADD CONSTRAINT uq_node_name     UNIQUE (name);
ALTER TABLE tag      ADD CONSTRAINT uq_tag_name      UNIQUE (name);

-- ---------- CHECK ----------
ALTER TABLE app_user ADD CONSTRAINT ck_user_role
  CHECK (role IN ('student', 'admin'));

ALTER TABLE edge ADD CONSTRAINT ck_edge_mode
  CHECK (mode IN ('walk', 'erickshaw', 'auto', 'metro', 'bus'));
ALTER TABLE edge ADD CONSTRAINT ck_edge_fare     CHECK (fare >= 0);
ALTER TABLE edge ADD CONSTRAINT ck_edge_distance CHECK (distance_m > 0);
ALTER TABLE edge ADD CONSTRAINT ck_edge_time     CHECK (time_min >= 0);
ALTER TABLE edge ADD CONSTRAINT ck_edge_no_loop  CHECK (from_node <> to_node);

ALTER TABLE place ADD CONSTRAINT ck_place_price  CHECK (price_level BETWEEN 1 AND 3);
ALTER TABLE place ADD CONSTRAINT ck_place_rating CHECK (avg_rating BETWEEN 0 AND 5);
ALTER TABLE place ADD CONSTRAINT ck_place_count  CHECK (review_count >= 0);
ALTER TABLE place ADD CONSTRAINT ck_place_lat    CHECK (lat BETWEEN -90 AND 90);
ALTER TABLE place ADD CONSTRAINT ck_place_lon    CHECK (lon BETWEEN -180 AND 180);

ALTER TABLE opening_hours ADD CONSTRAINT ck_hours_day CHECK (day BETWEEN 1 AND 7);

ALTER TABLE review   ADD CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5);
ALTER TABLE trip_leg ADD CONSTRAINT ck_leg_no        CHECK (leg_no >= 1);

-- ---------- FOREIGN KEYS ----------
ALTER TABLE edge ADD CONSTRAINT fk_edge_from FOREIGN KEY (from_node) REFERENCES node(node_id);
ALTER TABLE edge ADD CONSTRAINT fk_edge_to   FOREIGN KEY (to_node)   REFERENCES node(node_id);

ALTER TABLE place ADD CONSTRAINT fk_place_category FOREIGN KEY (category_id) REFERENCES category(category_id);
ALTER TABLE place ADD CONSTRAINT fk_place_node     FOREIGN KEY (node_id)     REFERENCES node(node_id);

ALTER TABLE food_outlet   ADD CONSTRAINT fk_food_place  FOREIGN KEY (place_id) REFERENCES place(place_id) ON DELETE CASCADE;
ALTER TABLE place_tag     ADD CONSTRAINT fk_ptag_place  FOREIGN KEY (place_id) REFERENCES place(place_id) ON DELETE CASCADE;
ALTER TABLE place_tag     ADD CONSTRAINT fk_ptag_tag    FOREIGN KEY (tag_id)   REFERENCES tag(tag_id)     ON DELETE CASCADE;
ALTER TABLE opening_hours ADD CONSTRAINT fk_hours_place FOREIGN KEY (place_id) REFERENCES place(place_id) ON DELETE CASCADE;

ALTER TABLE review ADD CONSTRAINT fk_review_user  FOREIGN KEY (user_id)  REFERENCES app_user(user_id) ON DELETE CASCADE;
ALTER TABLE review ADD CONSTRAINT fk_review_place FOREIGN KEY (place_id) REFERENCES place(place_id)   ON DELETE CASCADE;

ALTER TABLE trip     ADD CONSTRAINT fk_trip_user FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE;
ALTER TABLE trip_leg ADD CONSTRAINT fk_leg_trip  FOREIGN KEY (trip_id) REFERENCES trip(trip_id)     ON DELETE CASCADE;
ALTER TABLE trip_leg ADD CONSTRAINT fk_leg_edge  FOREIGN KEY (edge_id) REFERENCES edge(edge_id);
