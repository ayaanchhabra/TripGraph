-- schema/03_seed_reference.sql   (K)
-- Reference data: place categories. Names must match places.csv EXACTLY.
-- Run after 02_constraints.sql and before data/load_all.sql.

\set ON_ERROR_STOP on

INSERT INTO category (name, group_name) VALUES
  -- Food and drink
  ('Restaurants and dhabas',               'Food and drink'),
  ('Street food and chaat',                'Food and drink'),
  ('Cafes',                                'Food and drink'),
  ('Bakeries and sweet shops',             'Food and drink'),
  ('Juice, shakes and chai points',        'Food and drink'),
  ('Tiffin and mess services',             'Food and drink'),
  -- Study and work
  ('Stationery and photocopy/printing',    'Study and work'),
  ('Books and second-hand books',          'Study and work'),
  ('Study spots (libraries, quiet cafes)', 'Study and work'),
  -- Essentials
  ('Grocery and general stores',           'Essentials'),
  ('Medical stores and clinics',           'Essentials'),
  ('Laundry and ironing',                  'Essentials'),
  ('Salon and barber',                     'Essentials'),
  ('ATMs and banks',                       'Essentials'),
  -- Tech and repair
  ('Mobile and electronics repair',        'Tech and repair'),
  ('Mobile accessories and computer shops','Tech and repair'),
  -- Shopping and lifestyle
  ('Clothes and thrift shops',             'Shopping and lifestyle'),
  ('Gyms and sports',                      'Shopping and lifestyle'),
  -- Hangouts
  ('Parks and open spaces',                'Hangouts'),
  ('Gaming zones and cyber cafes',         'Hangouts'),
  ('Malls and movie halls',                'Hangouts');
