# Decay and ranking

The three formulas that make the product work. All **[built]** — they are the
prototype's actual behaviour, and all three are tuning knobs, not laws.

## Decay

For a person or a link, `days` is the time since the most recent meet-up
involving them.

```
decay = min(1, (max(0, days) / horizon) ^ 0.82)      // 0 = fresh, 1 = dead
signal strength = round((1 - decay) * 100) %
```

`horizon` defaults to **240 days**, adjustable 90–540. **[built]**

The exponent `0.82` makes decay slightly **front-loaded**: a relationship starts
visibly dimming early rather than falling off a cliff at the horizon. At default
horizon: 30 days ≈ 17% decayed, 90 days ≈ 43%, 180 days ≈ 76%, 240 days = 100%.

Someone with no recorded meet-up is treated as `days = 900` — *"never"*.

### Visual thresholds

| Decay | What you see |
| --- | --- |
| `< 0.22` | Link drawn as a solid line |
| `< 0.42` | Light packets run along the link; node core breathes |
| `> 0.22` | Link starts fragmenting into dashes that drift with a bell-curve wobble |
| `> 0.6` | Node ring starts mixing toward amber |
| `> 0.62` | Link colour starts mixing toward amber |
| `> 0.92` | Link opacity drops sharply — nearly gone |

The decay ring around a node is a countdown: it empties as decay rises.

Also: **the spring's rest length grows with decay** (`52 + decay * 74`) and its
stiffness falls. Neglected people physically drift away from you. That is the
single most important line of the whole simulation.

### Human labels

```
never / today / yesterday / N days ago (<21) / N weeks ago (<60) / N months ago
```

and for durations: `longer than you can remember / N days / N weeks / N months`.

## Nudge ranking — who is slipping away

Used by `nudge` (top 3) and to seed the group assembler.

```
score = days_since * (0.55 + closeness * 0.22)
```

Sorted descending, ghosts and yourself excluded.

The closeness weight is the point: **not seeing a close person for 60 days is
worse than not seeing an acquaintance for 60 days.** A `close = 3` person scores
1.21× per day, a `close = 1` person 0.77× — a ~1.6× spread.

> Note the current implementation compares `b.d * (0.55 + a.close)` against
> `a.d * (0.55 + b.close)` — it weights each side by the *other* person's
> closeness. That is almost certainly a slip; it happens to still rank roughly
> correctly because the terms are symmetric in aggregate, but do not port it
> verbatim. Compute a score per person, then sort. **[inferred]**

## Group assembler

Given an anchor (the weakest person, or one you seeded from a focus):

```
score = mutual_connections * 2
      + already_linked_to_anchor * 3
      + different_context * 1.6
      + min(3, days_since / 90)
```

Top 4 plus the anchor = **a group of five**.

What the weights encode:

- **Already knows the anchor (3)** — the strongest signal. A gathering works when
  people already have a thread to pull.
- **Mutual connections (2 each)** — cohesion. Unbounded, so a well-connected
  person can dominate.
- **Different context (1.6)** — a deliberate bonus for *crossing* circles. The
  assembler is not trying to rebuild an existing clique; it wants the table that
  would not otherwise happen.
- **Time since (up to 3)** — caps at 270 days so staleness can tip a choice but
  never drive it alone.

The UI justifies the result in one sentence: *"Everyone already knows someone
else here. The quietest of them hasn't seen you in {span} — one table fixes five
threads."*

**Group size is hardcoded to five** and the copy says "PING THE FIVE" / "Table
for six" (five plus you). Whether five is right, or should scale, is untested.
**[open]**

## Tuning these

All three formulas are guesses that produce a good demo. Before they meet real
data, be aware:

- The fixture graph is generated with a **closeness bias** — close people are
  given recent meet-ups by construction. So the nudge list looks sensible in the
  prototype partly because the data was built to make it look sensible.
  **[fixture]**
- One global `horizon` for every relationship is already flagged as questionable
  by the design itself. See [08-open-questions.md](08-open-questions.md).
