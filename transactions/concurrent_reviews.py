#!/usr/bin/env python3
"""
transactions/concurrent_reviews.py

Simulates many students reviewing the SAME place at the same moment, then checks whether
place.review_count and place.avg_rating match the real reviews.

  python3 transactions/concurrent_reviews.py --place-id 1 --reviews 20
  python3 transactions/concurrent_reviews.py --place-id 1 --reviews 20 --isolation serializable

Needs:  pip install psycopg2-binary
Connection: --dsn "dbname=tripgraph user=postgres"  (add host=... password=... if needed)
It creates temporary users (ids 970001 and up) and deletes them again at the end.
"""
import argparse
import threading
import psycopg2
from psycopg2 import errors, extensions

BASE_USER_ID = 970000


def worker(i, args, barrier, stats, lock):
    conn = psycopg2.connect(args.dsn)
    conn.set_session(isolation_level=args.isolation)
    cur = conn.cursor()
    barrier.wait()                       # everybody starts at the same moment
    retries = 0
    while True:
        try:
            cur.execute(
                "INSERT INTO review(user_id, place_id, rating) VALUES (%s, %s, %s)",
                (BASE_USER_ID + i, args.place_id, (i % 5) + 1),
            )
            conn.commit()
            break
        except (errors.SerializationFailure, errors.DeadlockDetected):
            conn.rollback()              # SERIALIZABLE may ask us to try again: that is correct behaviour
            retries += 1
    with lock:
        stats["retries"] += retries
    conn.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dsn", default="dbname=tripgraph user=postgres")
    ap.add_argument("--place-id", type=int, default=1)
    ap.add_argument("--reviews", type=int, default=20, help="how many reviewers at once")
    ap.add_argument("--isolation", default="read committed",
                    choices=["read committed", "repeatable read", "serializable"])
    args = ap.parse_args()
    args.isolation = {
        "read committed": extensions.ISOLATION_LEVEL_READ_COMMITTED,
        "repeatable read": extensions.ISOLATION_LEVEL_REPEATABLE_READ,
        "serializable": extensions.ISOLATION_LEVEL_SERIALIZABLE,
    }[args.isolation]

    admin = psycopg2.connect(args.dsn)
    admin.autocommit = True
    cur = admin.cursor()
    cur.execute("SELECT name FROM place WHERE place_id = %s", (args.place_id,))
    row = cur.fetchone()
    if row is None:
        raise SystemExit(f"No place with id {args.place_id}")
    cur.execute("DELETE FROM app_user WHERE user_id > %s AND user_id <= %s", (BASE_USER_ID, BASE_USER_ID + 10000))
    for i in range(1, args.reviews + 1):
        cur.execute("INSERT INTO app_user(user_id, name, email) VALUES (%s, %s, %s)",
                    (BASE_USER_ID + i, f"Concurrent {i}", f"conc{i}@tripgraph.test"))

    cur.execute("SELECT review_count, avg_rating FROM place WHERE place_id = %s", (args.place_id,))
    before = cur.fetchone()
    print(f"Place {args.place_id} ({row[0]}): before -> review_count={before[0]}, avg_rating={before[1]}")
    print(f"Starting {args.reviews} reviewers at the same moment ...")

    barrier = threading.Barrier(args.reviews)
    stats, lock = {"retries": 0}, threading.Lock()
    threads = [threading.Thread(target=worker, args=(i, args, barrier, stats, lock))
               for i in range(1, args.reviews + 1)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    cur.execute("SELECT count(*), COALESCE(round(avg(rating), 2), 0) FROM review WHERE place_id = %s", (args.place_id,))
    real_count, real_avg = cur.fetchone()
    cur.execute("SELECT review_count, avg_rating FROM place WHERE place_id = %s", (args.place_id,))
    stored_count, stored_avg = cur.fetchone()

    print(f"\nReal reviews in the review table : count={real_count}, avg={real_avg}")
    print(f"Stored on the place row (trigger): count={stored_count}, avg={stored_avg}")
    if stats["retries"]:
        print(f"(transactions that had to retry after a serialization failure: {stats['retries']})")
    if (stored_count, stored_avg) == (real_count, real_avg):
        print("\nRESULT: CORRECT. The stored numbers match the real reviews.")
    else:
        print(f"\nRESULT: LOST UPDATE. {real_count} reviews exist but the place says {stored_count}.")

    cur.execute("DELETE FROM app_user WHERE user_id > %s AND user_id <= %s", (BASE_USER_ID, BASE_USER_ID + 10000))
    print("(temporary users and their reviews deleted again)")
    admin.close()


if __name__ == "__main__":
    main()
