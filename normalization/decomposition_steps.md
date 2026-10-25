# Decomposition: from the messy table to BCNF

File: `normalization/decomposition_steps.md`
Uses: `functional_dependencies.md` (symbols, dependencies, keys). Final SQL: `normalized_tables.sql`.

Symbols (same as before): P place_id, PN place_name, C category_id, CN category_name, G group_name,
AD address, PL price_level, SD student_discount, N node_id, NN node_name, NK node_kind, CU cuisine,
V is_veg, T tag_name, D day, OT open_time, CT close_time, U user_id, UN user_name, UE user_email,
RT rating, E edge_id, M mode, DM distance_m, TM time_min, F fare, TO to_node_id, TN to_node_name,
TK to_node_kind.

## Step 0: the starting point

`tripgraph_messy`: 12 rows, 29 columns, one comma list (`tags`). The three anomalies in `messy_table.sql`
all come from the same cause: facts about one thing (a place, a category, a student) are copied into every
row that mentions it.

## Step 1: First Normal Form (1NF)

**Rule:** every value is a single, atomic value; there are no repeating groups; the table has a key.

**Violation:** `tags` holds 'veg, wifi, coffee, late-night' in one cell. That is a repeating group.

**Fix:** one row per tag. The 12 rows become 36 rows (place 3 has 4 tags and 3 rows, so 12 rows, and so on).
`normalized_tables.sql` does this with a view called `norm_demo.messy_1nf` (it splits the list with
`regexp_split_to_table`).

**Result:** relation R(P, PN, C, CN, G, AD, PL, SD, N, NN, NK, CU, V, T, D, OT, CT, U, UN, UE, RT, E, M, DM,
TM, F, TO, TN, TK) with candidate keys (P, T, D, E, U) and (P, T, D, E, UE). Everything below starts here.

## Step 2: Second Normal Form (2NF)

**Rule:** 1NF, and no non-key attribute depends on only a PART of a candidate key.

**Violations** (the key is (P, T, D, E, U); each left side is a proper part of it):

| Partial dependency | What is copied too often |
|---|---|
| P -> PN, C, AD, PL, SD, N, CU, V | place facts repeat for every tag, day, student and edge |
| (P, D) -> OT, CT | the opening hours repeat for every tag, student and edge |
| U -> UN, UE | the student's name and email repeat for every place reviewed |
| (U, P) -> RT | the rating repeats for every tag, day and edge |
| E -> N, TO, M, DM, TM, F | the edge facts repeat for every place using that edge |

**Fix:** move each group of dependent attributes, together with its left side, into its own table. The closures
from `functional_dependencies.md` tell us what each left side drags along:

| 2NF table | Attributes | Key |
|---|---|---|
| R_place | P, PN, C, CN, G, AD, PL, SD, N, NN, NK, CU, V | P |
| R_hours | P, D, OT, CT | (P, D) |
| R_user | U, UN, UE | U (and UE) |
| R_review | U, P, RT | (U, P) |
| R_edge | E, N, NN, NK, TO, TN, TK, M, DM, TM, F | E |
| R_link | P, T, D, E, U | (P, T, D, E, U), all attributes |

R_link is what is left of the original table: only the key columns. Every non-key attribute now depends on the
whole key of its own table.

## Step 3: Third Normal Form (3NF)

**Rule:** 2NF, and every non-key attribute depends on the key directly, not through another non-key attribute
(no transitive dependency).

**Violations:**

| Table | Transitive dependency | Meaning |
|---|---|---|
| R_place | P -> C -> CN, G | the group name is stored with every place of the category |
| R_place | P -> N -> NN, NK | the node name and kind are stored with every place at the node |
| R_edge | E -> N -> NN, NK | the node of the edge is described again in every edge |
| R_edge | E -> TO -> TN, TK | the target node is described again in every edge |

(CN -> C, NN -> N and TN -> TO point back at the key attribute, so they also expose the same problem: C, N and TO
are not keys of R_place or R_edge.)

**Fix:** pull each non-key determinant out together with what it determines, and keep it in the old table as a
foreign key.

| 3NF table | Attributes | Key(s) |
|---|---|---|
| place | P, PN, C, AD, PL, SD, N, CU, V | P |
| category | C, CN, G | C and CN |
| node | N, NN, NK | N and NN |
| node (second role) | TO, TN, TK | TO and TN |
| edge | E, N, TO, M, DM, TM, F | E |
| hours | P, D, OT, CT | (P, D) |
| app_user | U, UN, UE | U and UE |
| review | U, P, RT | (U, P) |
| link | P, T, D, E, U | all five |

The two node tables have the same shape, because the same real thing (a map node) plays two roles: the place's
node (N) and the target of an edge (TO). In the real database they are ONE table, `node`, and both
`place.node_id` and `edge.to_node` point at it (`edge.from_node` is the N of the edge).

## Step 4: Boyce-Codd Normal Form (BCNF)

**Rule:** for every dependency X -> Y in a table, X must be a superkey of that table.

**Check, table by table** (all dependencies that live inside the table):

| Table | Dependencies inside it | Left sides are superkeys? |
|---|---|---|
| place | P -> all other attributes | P is the key. Yes |
| category | C -> CN, G; CN -> C, G | C and CN are both keys. Yes |
| node | N -> NN, NK; NN -> N, NK | N and NN are both keys. Yes |
| edge | E -> all | Yes |
| hours | (P, D) -> OT, CT | Yes |
| app_user | U -> UN, UE; UE -> U, UN | U and UE are both keys. Yes |
| review | (U, P) -> RT | Yes |
| link | none (all attributes are the key) | Yes |

**Where 3NF and BCNF differ here.** In the full relation R, UE -> U is a violation of BCNF but not of 3NF:
UE is not a superkey of R, but U is a prime attribute (part of a candidate key), and 3NF allows that.
After Step 2 the pair U, UE sits in app_user, where UE IS a key, so the violation disappears. The same
reasoning covers CN -> C and NN -> N once category and node are separate tables.

**Result:** the tables of Step 3 are in BCNF. No further split is needed.

## Step 5: design steps beyond functional dependencies

These are not forced by BCNF, but they are part of the final design in `normalized_tables.sql`.

1. **The `link` table is dropped (Fourth Normal Form).** It only records which tag, day, student and edge happened
   to be listed in the same row. For one place these four lists are independent of each other (place -> tag,
   place -> day, place -> student, place -> edge are multivalued dependencies, not functional ones), so the
   combinations are not facts. What is useful in them is already in `place_tag`, `opening_hours`, `review` and
   the edges that leave the place's node. This is why the final design has no table with all five columns.
2. **`food_outlet` is split from `place`.** CU and V only apply to food places. A separate table, with
   `place_id` as key, avoids NULLs in every other place and matches the real schema.
3. **The tag list becomes `tag` and `place_tag`.** A many-to-many relationship needs a link table; `tag` gets a
   surrogate `tag_id`, as in the real schema.
4. **Derived data stays derived.** `avg_rating` and `review_count` are not in the analysis. The real `place`
   table keeps them on purpose (a trigger maintains them); see viva question 8.

## Proof 1: the decomposition is lossless (chase / tableau method)

A decomposition is lossless if joining the pieces gives back exactly the original rows. The tableau test:
make one row per table; in each row put the symbol `a` under the attributes the table contains and a unique
symbol `b` elsewhere; then apply the dependencies. If some row becomes all `a`, the decomposition is lossless.

Tables of the BCNF decomposition (9 rows of the tableau):

| Row | Table | Attributes |
|---|---|---|
| 1 | place | P, PN, C, AD, PL, SD, N, CU, V |
| 2 | category | C, CN, G |
| 3 | node | N, NN, NK |
| 4 | node (target role) | TO, TN, TK |
| 5 | hours | P, D, OT, CT |
| 6 | app_user | U, UN, UE |
| 7 | review | U, P, RT |
| 8 | edge | E, N, TO, M, DM, TM, F |
| 9 | link | P, T, D, E, U |

Follow row 9 (the link row). It starts with `a` only under P, T, D, E, U and `b` symbols in the other 24 columns.

1. P -> PN, C, AD, PL, SD, N, CU, V: rows 9 and 1 are both `a` under P, so row 9 takes the `a` of row 1 in
   PN, C, AD, PL, SD, N, CU, V.
2. C -> CN, G: row 9 now has `a` under C, as do rows 1 and 2, so row 9 gets `a` under CN and G.
3. N -> NN, NK: row 9 has `a` under N (from step 1), as do rows 3 and 8, so row 9 gets `a` under NN and NK.
4. (P, D) -> OT, CT: rows 9 and 5 agree on P and D, so row 9 gets `a` under OT and CT.
5. U -> UN, UE: rows 9 and 6 agree on U, so row 9 gets `a` under UN and UE.
6. (U, P) -> RT: rows 9 and 7 agree on U and P, so row 9 gets `a` under RT.
7. E -> N, TO, M, DM, TM, F: rows 9 and 8 agree on E, so row 9 gets `a` under TO, M, DM, TM, F.
8. TO -> TN, TK: row 9 has `a` under TO (step 7), as does row 4, so row 9 gets `a` under TN and TK.

Row 9 now has `a` in all 29 columns. **The decomposition is lossless.**

The same fact in the "common attribute is a key" form: every split above separated R into a table R1 and
the rest R2 such that the shared attributes form a key of R1 (for example splitting off app_user shares only U,
the key of app_user). A chain of such splits is lossless.

`normalized_tables.sql` also shows it on the data: joined with the link table, the new tables give back exactly
the 36 rows of `messy_1nf` (both EXCEPT counts are 0).

## Proof 2: the decomposition preserves the dependencies

A decomposition preserves dependencies if every dependency can be checked inside ONE table. Here every
dependency of the minimal cover has all its attributes inside one table, so the check is immediate:

| Dependencies | Table that enforces them | How |
|---|---|---|
| P -> PN, C, AD, PL, SD, N, CU, V | place (plus food_outlet for CU, V) | primary key |
| C -> CN, G and CN -> C | category | primary key and UNIQUE(name) |
| N -> NN, NK and NN -> N | node (both roles) | primary key and UNIQUE(name) |
| TO -> TN, TK and TN -> TO | node | same as the line above |
| (P, D) -> OT, CT | opening_hours | primary key |
| U -> UN, UE and UE -> U | app_user | primary key and UNIQUE(email) |
| (U, P) -> RT | review | primary key |
| E -> N (= from_node), TO (= to_node), M, DM, TM, F | edge | primary key |

All 29 dependencies are preserved. One rule is not a dependency and is not lost either: an edge in a row leaves
the place's own node, which is the join condition `place.node_id = edge.from_node`.

## Viva questions

1. **What is a functional dependency?** X -> Y means that whenever two rows have the same X they also have the
   same Y. Example: place_id -> address; the same place always has the same address.
2. **Why is (place_id, day, user_id, edge_id) the key of the messy table?** One row per place, opening-hours day,
   student and edge. Take any one of the four away and two rows could look the same. The 1NF version adds
   tag_name to that key.
3. **Which anomaly does the messy table show for each of insert, update and delete?** Insert: a new place or
   category cannot be stored without a review, hours day and edge. Update: changing an address in one row
   leaves the other rows with the old value. Delete: removing the only review of a place also removes the place
   and its category.
4. **What is the difference between 2NF and 3NF?** 2NF removes dependencies on a part of the key (opening hours
   depend on place AND day, the place name only on the place). 3NF removes dependencies through a non-key
   attribute (place -> category -> group name).
5. **Is the final design in BCNF, and what is the difference between 3NF and BCNF?** Yes, every determinant is a
   key. 3NF allows X -> A when A is part of a key; BCNF does not. In the full table, UE -> U is such a case; it
   is gone once app_user is its own table.
6. **What does lossless join mean, and how did you prove it?** The pieces joined together give exactly the
   original rows, no more and no fewer. Chase test: the row of the link table becomes all `a` after applying
   the dependencies. Also shown with SQL: both EXCEPT counts between the original and the rebuilt rows are 0.
7. **What is dependency preservation, and do you have it?** Every dependency can be checked inside a single
   table, so the database can enforce them with keys and UNIQUE constraints. Yes: all 29 are inside one
   table each.
8. **Why do `place.avg_rating` and `review_count` exist if they can be computed from reviews?** They are derived
   data, kept on purpose so that top-rated and search queries do not have to average reviews every time. They
   do not break BCNF (place_id determines them), but they can become stale, so a trigger recomputes them on
   every review insert, update and delete. The cost and benefit are discussed in `indexing/avg_rating_denormalization.md`.
