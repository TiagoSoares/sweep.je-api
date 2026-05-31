# Draw verification (algorithm version 1)

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

Shuffle the entries with label `"entry"` and the participants with label
`"participant"` — two independent streams.

### 3. Deal

Deal the shuffled entries round-robin to the shuffled participants:

```
for i, entry in shuffled_entries:
    participant = shuffled_participants[i mod shuffled_participants.length]
    assign entry -> participant
```

Because the participant order is shuffled, when entries don't divide evenly the
"extra" entries land on randomly chosen participants — this is the auto-balance
rule (§6.1 of SPEC.md).

### 4. Compare

Your `entry -> participant` assignments should exactly match the `allocations`
in the verification payload. If they do, the draw was fair and untampered.

## Reference implementation

The canonical implementation lives at `api/app/lib/seeded_random.rb`
(`SeededRandom`) and `api/app/services/draw_runner.rb` (`DrawRunner`). The web
app re-implements the same steps in TypeScript for in-browser verification.
