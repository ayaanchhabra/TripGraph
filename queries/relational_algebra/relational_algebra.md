# Relational algebra and tuple relational calculus (A)

Runnable SQL for everything below: `relational_algebra.sql` (same folder).
Table and column names are exactly those of the TABLES section.

## 0. Plain-language primer (read first)

Relational algebra (RA) is the *theory* behind SQL. Every operator takes one or two
relations (tables) and returns a new relation. SQL is the practical language; RA is how
the database thinks about a query internally.

| Symbol | Name | Meaning | SQL equivalent |
|---|---|---|---|
| σ_cond(R) | selection | keep the **rows** that satisfy cond | `WHERE` |
| π_cols(R) | projection | keep only some **columns**, remove duplicates | `SELECT DISTINCT cols` |
| R ⋈ S | natural join | combine rows of R and S that agree on common columns | `JOIN ... ON` |
| R ⋈_cond S | theta join | join with an explicit condition | `JOIN ... ON cond` |
| R × S | Cartesian product | every row of R with every row of S | `CROSS JOIN` |
| ρ_x(R) | rename | give R another name (needed for self joins) | table alias (`AS x`) |
| R ∪ S | union | rows in R or S | `UNION` |
| R − S | difference | rows in R but not in S | `EXCEPT` |
| R ÷ S | division | values of R that are paired with **every** row of S | no operator; double `NOT EXISTS` |

Important: RA works on **sets**, so there are never duplicate rows. That is why π maps to
`SELECT DISTINCT`. Plain SQL (without DISTINCT) works on **bags** and can return duplicates.

---

## RA1. Veg food outlets (σ, ⋈, π)
**Question:** names of all places that are veg food outlets.

```
π_name( place ⋈ σ_is_veg=true(food_outlet) )
```
Read from the inside out: first keep only the veg rows of `food_outlet`, then join them to
`place` on the shared column `place_id`, then keep only the `name` column.
```sql
SELECT DISTINCT p.name
FROM place p JOIN food_outlet f ON f.place_id = p.place_id
WHERE f.is_veg = true;
```
Viva tip: pushing σ *before* the join (as written) is what the optimizer does too: filter early,
join fewer rows.

## RA2. Places tagged "wifi" (three-table join)
```
π_name( place ⋈ place_tag ⋈ σ_name='wifi'(tag) )
```
Problem: `place` and `tag` both have a column called `name`, and a *natural* join would try to
match them. So write it with explicit attributes (rename the tag column first):
```
π_place.name( place ⋈_{place.place_id = place_tag.place_id} place_tag
                     ⋈_{place_tag.tag_id = t.tag_id} σ_{t.name='wifi'}(ρ_t(tag)) )
```
```sql
SELECT DISTINCT p.name
FROM place p
JOIN place_tag pt ON pt.place_id = p.place_id
JOIN tag t        ON t.tag_id = pt.tag_id
WHERE t.name = 'wifi';
```
`place_tag` is the many-to-many bridge between `place` and `tag`, which is why two joins are needed.

## RA3. Places with no review (set difference)
```
π_place_id(place) − π_place_id(review)
```
"All place ids, minus the ones that appear in review." Only works because both sides have the
same single column (union-compatible).
```sql
SELECT place_id FROM place
EXCEPT
SELECT place_id FROM review;
```
Alternative in SQL: `LEFT JOIN ... WHERE review.place_id IS NULL`, or `NOT EXISTS`.

## RA4. Cheap OR student-discount places (union)
```
π_place_id,name( σ_price_level=1(place) )  ∪  π_place_id,name( σ_student_discount=true(place) )
```
```sql
SELECT place_id, name FROM place WHERE price_level = 1
UNION
SELECT place_id, name FROM place WHERE student_discount = true;
```
A place that is both cheap and discounted appears **once**, because union removes duplicates
(`UNION ALL` would keep both copies). Same result as a single `WHERE ... OR ...`.

## RA5. Users who reviewed EVERY student-discount place (division)
Let
```
D  = π_place_id( σ_student_discount=true(place) )        -- the "every" set
R  = π_user_id, place_id( review )                        -- who reviewed what
```
Then
```
π_user_id,name( app_user ⋈ ( R ÷ D ) )
```
`R ÷ D` returns the `user_id` values that are paired in R with **every** `place_id` in D.
Division is the RA form of "for all" questions.

SQL has no ÷, so use the double negation "there is no discount place this user has *not* reviewed":
```sql
SELECT u.user_id, u.name
FROM app_user u
WHERE NOT EXISTS (
  SELECT 1 FROM place p
  WHERE p.student_discount = true
    AND NOT EXISTS (
      SELECT 1 FROM review r
      WHERE r.user_id = u.user_id AND r.place_id = p.place_id));
```
Equivalent expansion of division using basic operators:
`R ÷ D = π_user(R) − π_user( (π_user(R) × D) − R )`. (Users minus the users for whom some
required place is missing.)

## RA6. Pairs of places that share a map node (rename + self join)
Two places can sit on the same map node (for example Chaat Corner and Chai Tapri).
```
π_p1.name, p2.name( σ_{p1.node_id = p2.node_id ∧ p1.place_id < p2.place_id}( ρ_p1(place) × ρ_p2(place) ) )
```
We need ρ because `place` appears twice; `p1.place_id < p2.place_id` removes pairs of a place
with itself and the mirror duplicate (A,B) / (B,A).
```sql
SELECT p1.name, p2.name, p1.node_id
FROM place p1
JOIN place p2 ON p1.node_id = p2.node_id AND p1.place_id < p2.place_id;
```
`σ(R × S)` with a join condition is exactly the theta join `R ⋈_cond S`.

---

## TRC. Tuple relational calculus
**Question:** names of places that have at least one review and where **every** review is 4 or more.

```
{ p.name | p ∈ place
           ∧ ∃r ∈ review ( r.place_id = p.place_id )
           ∧ ¬∃r ∈ review ( r.place_id = p.place_id ∧ r.rating < 4 ) }
```
Reading:
- `p` is a **tuple variable** that ranges over the rows of `place`.
- `{ p.name | condition }` means "the set of `p.name` for every `p` for which condition is true".
- `∃` = "there exists", `¬` = "not", `∧` = "and".
- The last line is the universal "∀ review of p: rating ≥ 4", written as "there is no review of p with rating < 4".
- The first `∃` line is a *safety* condition: without it, places with **no** reviews would qualify trivially.

```sql
SELECT p.name
FROM place p
WHERE EXISTS     (SELECT 1 FROM review r WHERE r.place_id = p.place_id)
  AND NOT EXISTS (SELECT 1 FROM review r WHERE r.place_id = p.place_id AND r.rating < 4);
```
Why TRC is *safe* here: every variable is bound to a real table (`place`, `review`), so the
answer is finite. An unsafe expression such as `{ t | ¬(t ∈ place) }` would describe infinitely
many tuples and is not allowed.

**RA vs TRC in one line:** RA is *procedural* (do these operations in this order); TRC is
*declarative* (describe what the answer looks like). SQL is mostly declarative, so it sits
closer to TRC, but the optimizer turns it into RA internally.

## Viva questions to be ready for
1. Why is projection written with DISTINCT in SQL? (RA relations are sets.)
2. Why is division not a basic operator? (Expressible with π, ×, −; shown in RA5.)
3. What is the difference between ⋈ and ×? (Join = product + selection on matching columns.)
4. Why do we need ρ in RA6? (The same relation twice; names must be distinct.)
5. What does "union-compatible" mean for RA3/RA4? (Same number of columns with compatible types.)
6. What is a safe TRC expression? (One whose result is finite: variables range over real relations.)
