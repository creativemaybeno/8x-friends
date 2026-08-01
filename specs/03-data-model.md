# Data model

## Entities in the prototype **[built]**

### Person

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | |
| `name` | string | |
| `group` | enum | Shared context — see below |
| `close` | 1–3 | Closeness tier. Affects node size and nudge ranking. Never editable in the UI. **[open]** |
| `bday` | string | Day + month only, no year (`"04 Mar"`) |
| `via` | string \| null | Free text: how you met / who introduced them (`"sister"`, `"via Tomás"`, `"met at Bloc Fabrik"`) |
| `me` | bool | Exactly one person is you |

v2 adds, for people who are also 8x users:

| Field | Type | Notes |
| --- | --- | --- |
| `on8x` | bool | |
| `gsize` | int | Size of their own graph |
| `greach` | int | Their total reach including their friends-of-friends |

### Context (`group`)

A closed enum in the prototype, each with a display label and a colour: **[built]**

`family` Family · `climb` Climbing · `work` Work · `uni` University ·
`hood` Neighbourhood

The brief calls for "shared context (work, school, climbing gym)" **[brief]** —
open-ended by nature. A fixed enum will not survive contact with real users; this
should almost certainly become user-defined tags. **[inferred]** **[open]**

Note a person has exactly **one** context in the prototype, but real people
belong to several (a colleague who also climbs). **[open]**

### Relationship (link)

Undirected, between two people. Carries no data of its own — its entire state is
*derived* from the meet-up events the two people share. That is the model's best
idea and should be preserved: **a relationship is nothing but the events in it.**

### Event (meet-up)

| Field | Type | Notes |
| --- | --- | --- |
| `day` | int | Days ago. A prototype shortcut — needs to be a real timestamp. |
| `who` | person[] | Everyone present, including you when you were there |
| `place` | string | Free text |

Events are the single source of truth for "when did we meet". Both per-person
and per-link recency are computed from them, never stored.

Events can exist **without you** — the prototype generates meet-ups among your
friends that you were not at (~18% of them), which is what makes
*"{name} saw them more recently"* possible. Where that information would come
from in a real app is unspecified. **[open]**

### Invitation — v2

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | |
| `from` | person | Sender |
| `people` | person[] | Everyone invited |
| `place` | string | Free text, includes the time (`"Bloc Fabrik, Thursday 19:00"`) |
| `day` | int | Proposed day offset |
| `state` | enum | `pending` / `accepted` / `declined` |

Accepting converts the invitation into an Event dated today.

### Ghost — v2

An anonymous friend-of-a-friend, materialised by merging a friend's graph. Has an
owner, a radius, and **no name and no initials, ever**. If a ghost corresponds to
someone you already know, it flies into your existing node and pops — the graph
de-duplicates in front of you. See [05-social-layer.md](05-social-layer.md).

Ghosts are a *client-side visual* in the prototype, generated from a seed.
Whether the server ever materialises per-person ghost rows, or only returns
counts, is a real architecture decision with privacy consequences. **[open]**

### Subscription — v2

A single boolean in the prototype. See [06-business-model.md](06-business-model.md).

## Proposed Postgres shape **[inferred]**

Nothing below was decided in the design project. It is a starting point for
`supabase/migrations/`, not a specification.

```
profiles          id (= auth.users.id), display_name, created_at
people            id, owner_id → profiles, name, birthday_day, birthday_month,
                  closeness (1..3), met_via text, linked_profile_id → profiles (nullable)
contexts          id, owner_id, label, colour
people_contexts   person_id, context_id                      -- many-to-many
relationships     id, owner_id, a_person_id, b_person_id      -- unordered pair, unique
events            id, owner_id, occurred_on date, place text, created_at
event_people      event_id, person_id
invitations       id, sender_profile_id, place text, proposed_for date, state
invitation_people invitation_id, person_id, response
subscriptions     profile_id, status, current_period_end
```

Points worth deciding early:

- **`people` are owned, not shared.** Your "Marta" and your friend's "Marta" are
  different rows. `linked_profile_id` is the optional bridge when that person is
  also an 8x user — that is the only thing the social layer needs.
- **Everything is per-owner, so RLS is simple**: `owner_id = auth.uid()` on
  almost every table. Invitations are the one cross-owner surface and need real
  thought.
- **Store dates, derive decay.** Never persist a decay value; it is a pure
  function of `now - last_event` (see [04](04-decay-and-ranking.md)) and the
  time-scrub feature depends on being able to recompute it for any past instant.
- **Birthdays have no year** in the design. Storing day+month avoids inventing
  data you do not have.

## Seed data

The prototype's fixture graph — 25 people, 5 contexts, 50 relationships, ~79
events over 18 months, 7 friends on 8x — is a good shape for `supabase/seed.sql`:
big enough that the layouts, nudges and group assembler all produce interesting
output, small enough to reason about. It is generated deterministically from
seeds `80126` and `4711` in the prototype. **[fixture]**
