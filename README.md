# TripGraph

# TripGraph

A database-centered student trip and services planner for the area around NSUT, Dwarka, Delhi.

A 4-person DBMS course project at NSUT, built on PostgreSQL.

## 1. What is TripGraph?

NSUT students need food, stationery, essentials and hangouts outside campus, and need to know how to reach them (walk, e-rickshaw, auto, metro) and what it costs. General map apps do not handle student constraints such as vegetarian only, under Rs 100, open late, student discount, or total fare under Rs 50.

TripGraph stores this knowledge in a structured PostgreSQL database:

- A small hand-built map of the area as nodes and edges
- A directory of places with categories, tags, opening hours and reviews
- Rules inside the database (constraints, triggers, views) that keep the data valid

The database does the thinking: routing, filtering, ranking and validation all happen in SQL. The user interface is intentionally minimal.

## 2. Scope

**In scope**

- About 15 hand-entered map nodes and 30 edges
- Places across 21 categories, with tags, opening hours and reviews
- Cheapest-route queries with total fare and time (recursive CTE)
- Triggers, views, constraints, roles (student and admin)
- Normalization to BCNF, indexing benchmarks, concurrency demo

**Not in scope**

- No OpenStreetMap import
- No PostGIS or pgRouting
- No map UI
- No row-level security
- No NoSQL implementation (report paragraph only)
- No Docker
- No submission or approval flow
- No place versioning

## 3. Tech Stack

| Purpose | Tool |
|---|---|
| Database | PostgreSQL 15+ |
| Procedural code | PL/pgSQL |
| DB tools | psql, pgAdmin |
| Backend | Python (Flask, psycopg2) |
| Diagrams | draw.io, dbdiagram.io |
| Version control | Git / GitHub |

## 4. Team and Roles

| Member | Role |
|---|---|
| A (leader) | Map, data, search and performance |
| K | Schema, trip logic and rules |
| S | User features, access control and interface |
| AJ | ER diagram, data entry and documentation |

Details:

- **A:** mini map (nodes and edges), bulk data generation, indexes and EXPLAIN ANALYZE benchmarks, full-text search, relational algebra queries
- **K:** DDL and constraints, recursive CTE trip queries, triggers, views, lost-update demo
- **S:** roles and GRANT/REVOKE, sample users and reviews, favorites, normalization write-up, Flask app
- **AJ:** ER diagram, relational schema diagram, sample CSVs, README, test records, report, PPT, viva Q&A sheet

## 5. Repository Structure

```
tripgraph/
  README.md                 (AJ)
  schema/                   (K)   tables, constraints, reference data
  data/
    map/                    (A)   nodes.csv, edges.csv, loading scripts
    csv/                    (AJ)  places, tags, opening hours
    sample_data/            (S)   users, reviews, favorites
  queries/
    trips/                  (K)
    views/                  (K, S)
    relational_algebra/     (A)
  triggers/                 (K)
  indexing/                 (A)   benchmarks/
  transactions/             (K)   lost update demo and fix
  recovery/                 (A)   optional crash recovery demo
  security/                 (S)   roles and grants
  app/                      (S)   backend/, frontend/
  normalization/            (S)   messy table to BCNF
  tests/                    (K, AJ) tests (K), recorded results (AJ)
  docs/                     (AJ)  er_diagram/, report/, presentation/
```

## 6. Setup

> TODO (after K confirms the final file names): add the exact commands.

Prerequisites: PostgreSQL 15 or later, psql, Python 3.10+ (for the app only).

Planned run order:

1. Create the database
2. Run the files in `schema/` in numeric order
3. Load the map from `data/map/`
4. Load the CSVs from `data/csv/` and sample data from `data/sample_data/`
5. Create triggers, then views
6. Run security scripts
7. Optionally run the app

## 7. Running the Demos

> TODO (fill in as each teammate finishes their part)

| Demo | Folder | Owner |
|---|---|---|
| Cheapest route query | `queries/trips/` | K |
| Indexing benchmark | `indexing/` | A |
| Lost update and fix | `transactions/` | K |
| Roles (student vs admin) | `security/` | S |
| Normalization | `normalization/` | S |
## 8. Git Workflow

- `main` must always work
- One branch per person: `a/`, `k/`, `s/`, `aj/`
- Small commits with a prefix, for example `k: add trip_leg trigger`
- Pull from `main` daily
- Merge through a pull request reviewed by one other member
- Never commit `.env` files or large data dumps

## 9. Documentation

Diagrams, the report, the presentation and the viva Q&A sheet are in `docs/`.
