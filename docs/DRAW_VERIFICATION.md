# Draw verification (algorithm version 2)

Every sweepstake draw is **reproducible from its published seed**. The
`GET /api/v1/s/:share_token/verification` endpoint returns everything you need to
recompute the result yourself and confirm it matches what the platform recorded.

## What you get

```json
{
  "verification": {
    "algorithm_version": 1,
    "seed": "<64 hex chars>",
    "run_at": "2026-07-01T18:00:00Z",
    "trigger": "manual",
    "participant_order": [{ "id": "<ulid>", "name": "Alice" }, ...],
    "entry_order":       [{ "id": "<ulid>", "name": "Brazil" }, ...],
    "allocations":       [{ "entry_id": "<ulid>", "participant_id": "<ulid>" }, ...]
  }
}
```

- `participant_order` / `entry_order` are the **canonical pre-shuffle orderings**
  (participants by registration time; entries by position).
- `allocations` is the recorded result to check your recomputation against.

## The algorithm

Given the `seed`, the canonical `entry_order` (E) and `participant_order` (P):

### 1. Seeded random integers

For a stream `label` and integer `counter`, the random value is:

```
h   = SHA256( seed + ":" + label + ":" + counter )   // hex string
v   = first 16 hex chars of h, parsed as a 64-bit integer
int = v mod n                                          // uniform-ish in [0, n)
```

> Integers are reduced modulo `n`. For sweepstake-sized `n` (tens of items) the
> modulo bias is negligible.

### 2. Fisher–Yates shuffle

To shuffle an array `A` using stream `label`:

```
counter = 0
for i from (A.length - 1) down to 1:
    j = int(label, counter, i + 1)
    counter = counter + 1
    swap A[i], A[j]
```

### 3. Deal in rank-ordered pots

`entry_order` (E) is the teams in **rank order** — best odds first. Deal them in
that order, one pot at a time, where a pot is a block the size of the participant
count `N = P.length`. For each pot, shuffle the **participant** list with a
pot-specific stream and hand pot entry `j` to shuffled participant `j`:

```
for pot_index, pot in enumerate(chunks of E, size N):     # E[0..N-1], E[N..2N-1], …
    shuffled = fisher_yates_shuffle(P, label = "pot:" + pot_index)
    for j, entry in enumerate(pot):
        assign entry -> shuffled[j]
```

So every player gets exactly one team from each full pot — the favourites (pot 0)
spread one-per-person, the next band shared out, and so on. When the teams don't
divide evenly, the final partial pot (the lowest-ranked leftovers) goes to the
first `teams mod players` players of that pot's shuffle — a random subset.

### 4. Compare

Your `entry -> participant` assignments should exactly match the `allocations`
in the verification payload. If they do, the draw was fair and untampered.

## Reference implementation

The canonical implementation lives at `api/app/lib/seeded_random.rb`
(`SeededRandom`) and `api/app/services/draw_runner.rb` (`DrawRunner`). The web
app re-implements the same steps in TypeScript for in-browser verification.
