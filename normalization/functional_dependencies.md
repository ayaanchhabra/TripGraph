# Functional dependencies of the messy table

File: `normalization/functional_dependencies.md`
Works on: `normalization/messy_table.sql` (table `tripgraph_messy`)
Next: `decomposition_steps.md`

## 1. The relation and its attributes

`tripgraph_messy` has one row per (place, day, student, edge) and a comma list of tags.
A comma list is not atomic, so the first thing normalization does (step 1NF, see the next file)
is split it into one row per tag. All work below uses that 1NF relation, called **R**.
Short symbols are used so the closures stay readable.

| Symbol | Column | Symbol | Column |
|---|---|---|---|
| P | place_id | U | user_id |
| PN | place_name | UN | user_name |
| C | category_id | UE | user_email |
| CN | category_name | RT | rating |
| G | group_name | E | edge_id |
| AD | address | M | mode |
| PL | price_level | DM | distance_m |
| SD | student_discount | TM | time_min |
| N | node_id (node the place is reached from) | F | fare |
| NN | node_name | TO | to_node_id (where the edge leads) |
| NK | node_kind | TN | to_node_name |
| CU | cuisine | TK | to_node_kind |
| V | is_veg | T | tag_name (exists after 1NF) |
| D | day | OT | open_time |
|   |   | CT | close_time |

R has 29 attributes. Derived columns of the real `place` table (`avg_rating`, `review_count`) are
left out on purpose: they can be computed from reviews, so they are not independent facts
(see the viva questions in `decomposition_steps.md`).

## 2. The functional dependencies

A dependency X -> Y means: two rows with the same X always have the same Y.
Every one of them comes from a rule in `schema/01_tables.sql` or `schema/02_constraints.sql`,
or from plain meaning, and all of them were checked against the 12 example rows.

| # | Dependency | Why it holds |
|---|---|---|
| 1 | P -> PN, C, AD, PL, SD, N, CU, V | `place_id` is the primary key of `place`; `cuisine` and `is_veg` come from `food_outlet`, whose key is `place_id` (empty for non-food places) |
| 2 | C -> CN, G | `category_id` is the primary key of `category` |
| 3 | CN -> C | `uq_category_name`: a category name is unique |
| 4 | N -> NN, NK | `node_id` is the primary key of `node` |
| 5 | NN -> N | `uq_node_name`: a node name is unique |
| 6 | (P, D) -> OT, CT | primary key of `opening_hours` is (place_id, day) |
| 7 | U -> UN, UE | `user_id` is the primary key of `app_user` |
| 8 | UE -> U | `uq_user_email`: an email is unique |
| 9 | (U, P) -> RT | primary key of `review` is (user_id, place_id): one rating per student per place |
| 10 | E -> N, TO, M, DM, TM, F | `edge_id` is the primary key of `edge`; the edge in a row leaves the place's own node, so its `from_node` is N |
| 11 | TO -> TN, TK | the target of an edge is a node, so `node_id` -> name, kind (same rule as 4, other role) |
| 12 | TN -> TO | node names are unique (same rule as 5, other role) |

Things that are NOT dependencies (good viva material):

* PN -> P does not hold. Place names are not unique in `place` (there is no UNIQUE on `name`).
* N -> P does not hold. Places 5 and 6 share one node; places 11 and 12 share one node.
* P -> RT does not hold. A place has many reviews, so a rating needs the student too.
* P -> D does not hold. A place has seven opening-hours days.

NULLs: for non-food places CU and V are NULL. For dependency purposes NULL counts as one value,
so P -> CU, V still holds (the same place always gives the same NULL).

## 3. Attribute closure, step by step

The closure X+ is everything X determines. Start with X, then keep applying dependencies whose
left side is already inside the set, until nothing new is added.

**P+ (what a place determines)**

1. Start: {P}
2. Dependency 1 (P -> ...): {P, PN, C, AD, PL, SD, N, CU, V}
3. Dependency 2 (C -> CN, G): add CN, G
4. Dependency 4 (N -> NN, NK): add NN, NK
5. Dependencies 3 and 5 add nothing new.

P+ = {P, PN, C, CN, G, AD, PL, SD, N, NN, NK, CU, V} (13 attributes). It misses T, D, U, E and
many more, so P alone is not a key of R.

**(P, D)+**

1. P+ as above (13 attributes), plus D.
2. Dependency 6 ((P, D) -> OT, CT): add OT, CT.

(P, D)+ = P+ plus D, OT, CT (16 attributes).

**E+ (what an edge determines)**

1. Start: {E}
2. Dependency 10: {E, N, TO, M, DM, TM, F}
3. Dependency 4 (N -> NN, NK): add NN, NK
4. Dependency 11 (TO -> TN, TK): add TN, TK

E+ = {E, N, NN, NK, TO, TN, TK, M, DM, TM, F} (11 attributes).

**(U, P)+**

1. Start: {U, P}
2. Dependency 7 (U -> UN, UE): add UN, UE
3. Dependency 9 ((U, P) -> RT): add RT
4. Dependency 1 (P -> ...) and then 2 and 4: add the 11 place attributes from P+

(U, P)+ = P+ plus U, UN, UE, RT (17 attributes).

**{P, T, D, E, U}+ (the key of R)**

1. Start: {P, T, D, E, U}
2. P -> ...: add PN, C, AD, PL, SD, N, CU, V
3. C -> ...: add CN, G
4. N -> ...: add NN, NK
5. (P, D) -> OT, CT: add OT, CT
6. U -> UN, UE: add UN, UE
7. (U, P) -> RT: add RT
8. E -> ...: add TO, M, DM, TM, F (N is already there)
9. TO -> TN, TK: add TN, TK

The set now holds all 29 attributes, so {P, T, D, E, U} is a superkey of R.

## 4. Candidate keys

**Which attributes must be in every key?** An attribute that never appears on the right side of any
dependency cannot be derived from anything, so it has to be in the key itself. Looking at the right
sides of dependencies 1 to 12: P, T, D and E never appear (U appears only in UE -> U).
So every key contains **P, T, D and E**.

**Is that enough?** {P, T, D, E}+ gives the place attributes (from P), OT and CT (from P and D) and the
edge attributes (from E), but not U, UN, UE or RT. A student must be added. Adding U works (section 3).
Adding UE also works, because UE -> U.

**Candidate keys of R (checked by trying every smaller combination, nothing else works):**

1. {P, T, D, E, U} = (place_id, tag_name, day, edge_id, user_id)
2. {P, T, D, E, UE} = (place_id, tag_name, day, edge_id, user_email)

No proper subset of either one reaches all 29 attributes, so both are minimal. There is no third key,
because P, T, D, E are forced and exactly one of U or UE completes them.

In the stored `tripgraph_messy` (before the tags are split) T is not an attribute yet, so its keys are
(place_id, day, user_id, edge_id), the primary key, and (place_id, day, user_email, edge_id), the UNIQUE
constraint. Both are declared in `messy_table.sql`.

## 5. Minimal cover

A minimal cover is the smallest set of dependencies that says the same thing: single attribute on the
right side, no unnecessary attribute on the left, no dependency that the others already imply.

**Step A: one attribute on every right side.** Splitting dependencies 1 to 12 gives 29 dependencies:

* P -> PN, P -> C, P -> AD, P -> PL, P -> SD, P -> N, P -> CU, P -> V (8)
* C -> CN, C -> G, CN -> C (3)
* N -> NN, N -> NK, NN -> N (3)
* (P, D) -> OT, (P, D) -> CT (2)
* U -> UN, U -> UE, UE -> U (3)
* (U, P) -> RT (1)
* E -> N, E -> TO, E -> M, E -> DM, E -> TM, E -> F (6)
* TO -> TN, TO -> TK, TN -> TO (3)

**Step B: no extra attribute on a left side.** Only two dependencies have two attributes on the left.

* (P, D) -> OT: is P alone enough? P+ (section 3) does not contain OT. Is D alone enough? D+ = {D}.
  Neither, so nothing can be removed. The same test for CT gives the same answer.
* (U, P) -> RT: U+ = {U, UN, UE} and P+ do not contain RT. Nothing can be removed.

**Step C: no dependency that the others already imply.** For each dependency X -> A, take it out, compute X+
with the remaining 28, and see whether A still appears. It never does. The reasons, grouped:

* Every attribute on the right of the place, category, node, user and edge dependencies can only be reached
  through its own dependency. Example: remove P -> C; then P+ = {P, PN, AD, PL, SD, N, CU, V, NN, NK}, no C.
  Example: remove E -> N; then E+ = {E, TO, TN, TK, M, DM, TM, F}, no N (N is reachable from P, but a different
  left side).
* The pairs CN <-> C, NN <-> N, UE <-> U, TN <-> TO each depend on each other. Remove one direction and the
  other direction cannot rebuild it: remove CN -> C and CN+ = {CN}.

**Result.** The set in section 2 is already minimal. As 12 grouped dependencies:

```
P       -> PN, C, AD, PL, SD, N, CU, V
C       -> CN, G
CN      -> C
N       -> NN, NK
NN      -> N
(P, D)  -> OT, CT
U       -> UN, UE
UE      -> U
(U, P)  -> RT
E       -> N, TO, M, DM, TM, F
TO      -> TN, TK
TN      -> TO
```

Next file: `decomposition_steps.md` uses these dependencies and keys to split R.
