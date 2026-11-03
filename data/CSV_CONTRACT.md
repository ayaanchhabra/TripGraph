# Place CSV contract

The place-data producer writes these three files into `data/csv/`. The place loader reads them.
Header row required. UTF-8. Empty cell = NULL. Wrap text containing commas in "double quotes".

## places.csv
place_id,name,category_name,address,lat,lon,price_level,student_discount,node_name,cuisine,is_veg

- place_id: unique integer, you choose (1, 2, 3...). Other CSVs refer to it.
- category_name: must match the `category.name` seed EXACTLY (spelling, case, "and").
- node_name: must match a `node.name` in data/map/nodes.csv EXACTLY (e.g. `Cafe X`, `Chaat Corner`).
  Several places can share one node (a node is a landmark/stop, not a shop).
- price_level: 1, 2 or 3.  student_discount: true/false.
- cuisine, is_veg: fill ONLY for Food and drink places; leave empty for the rest.
  Every Food and drink place must have is_veg filled (it creates its food_outlet row).
- lat/lon: roughly 28.58-28.64 N, 77.00-77.08 E (Dwarka).

## place_tags.csv
place_id,tag_name

- One row per (place, tag). Tags are lower-cased and created automatically.
- Use a consistent vocabulary: veg, non-veg, chai, cheap, wifi, late-night, printing...
- Every place should have at least one tag.

## opening_hours.csv
place_id,day,open_time,close_time

- day: 1-7 (ISO: 1 = Monday ... 7 = Sunday)
- time format HH:MM (24 hour). One row per place per day (7 rows per place), no duplicates.

Working examples are in `data/csv_examples/`.
