# Features

The app has no screens. It has **modes** — states of one continuous force
simulation. Switching mode re-runs the same simulation with different target
forces and a different camera, so the graph reassembles rather than cutting.
**[design]**

Everything below is **[built]** in the prototype unless marked otherwise.

## Mode inventory

| Mode | In | Purpose |
| --- | --- | --- |
| `boot` | v1 | Cold start — the graph assembles from nothing |
| `home` | v1 | The graph, idle. Three layouts. |
| `focus` | v1 | One person centred, their neighbours arranged around them |
| `log` | v1 | Record a meetup by tapping people |
| `add` | v1 | Drop a new person in and wire them up |
| `nudge` | v1 | The faded people pull at you |
| `group` | v1 | Assemble a group worth gathering |
| `time` | v1 | Scrub the whole graph through 18 months |
| `reach` | v2 | Zoom out to the full reach, including anonymous friends-of-friends |
| `invites` | v2 | Incoming and outgoing invitations |
| `propose` | v2 | Compose an invitation |
| `pay` | v2 | The paywall |

## boot

Wordmark flickers over a dark field, caption *"assembling your graph"*, nodes
fade and spring in staggered over ~2.6 s, then it settles into `home`. Tapping
anywhere skips it. Camera starts zoomed out and eases in.

## home — the graph

Pan by dragging the background, zoom by wheel/pinch or the +/− buttons, tap a
node to focus, drag a node and the springs answer live. A recenter button resets
the camera. Node labels show at high zoom or for close friends, configurable
(`smart` / `always` / `never`).

Three layouts, switched from a segmented control, each a different force
configuration on the *same* simulation: **[brief]** **[built]**

| Layout | Rule | Best for |
| --- | --- | --- |
| **WEB** | Free force layout | Truest picture of who knows who; clusters emerge on their own |
| **ORBIT** | You at the centre, radius = time since you last met | Drifting people literally fall to the outer rings |
| **STRATA** | Islands by shared context | Spotting a group you could assemble |

Switching mid-drag is supported and is explicitly called out as a thing to try.

A hint line reports the current layout's meaning and the graph's size.

## focus — a person

Centres the person, pulls their direct connections into a ring at close radius,
pushes everyone else out and dims them to ~7%. Camera zooms in. A sheet rises
with:

- Name, context chip, and **how you met / who introduced them**
- **Last together** (colour-coded by decay) and **birthday**
- **Signal strength** — a percentage and a bar, coloured by decay
- A warm one-line read on the relationship, which changes with decay:
  - decayed: *"It's been a while since {name}. The thread is coming apart — one message would fix it."*
  - drifting: *"You and {name} are drifting a little. You could bring {mutual} along."*
  - healthy: *"You and {name} are in good rhythm right now."*
- Context chips, including *"also knows {name}"* for up to 3 mutuals
- **Shared history** — up to 6 past meet-ups: when, where, and who else was there
- Actions: **WE MET UP** (→ `log` pre-filled) and **BUILD A GROUP** (→ `group` seeded with them)
- v2 only: a social row — invite them to 8x, or pull in their graph — and **PROPOSE**

## log — record a meetup

The ultra-fast path the user asked for. **[brief]**

Tap people directly on the graph; selected nodes pull into a huddle at close
radius with a white dashed ring, everyone else dims to 42%. The sheet shows the
running selection as a sentence (*"Marta, Tomás and Sofia"*), four when-chips
(Today / Yesterday / 3 days / Last week), a confirm button that counts the
selection, and *"+ someone new was there"* → `add`.

Confirming writes the event, recomputes decay for everyone involved, and toasts
*"{names} are lit up again."* The links visibly re-ignite.

**No place field in the logging flow** — events carry a place internally and the
seeded ones have real place names, but a user-logged event is stored as
*"you logged this"*. The agreed scope said "who, when, where". **[open]**

## add — a new person

Two steps. Name first; the node drops in at the centre, unattached. Then tap
everyone who already knows them and a new tie springs into place per tap, with a
running count. New people default to the *Neighbourhood* context and closeness 1.

## nudge — the graph pulls at you

The three most-faded people stretch away from centre on elastic tethers,
oscillating; everyone else dims to 13%. Camera pulls way back. The sheet is
headed *"THE GRAPH IS PULLING AT YOU"* and lists each person with their initials,
context, days since, and who saw them more recently than you did. Tapping one
focuses them. **SEE THEM ALL AT ONCE** sends all three into `log` pre-selected.

This is the amber surface — the only warm colour in the app.

Ranking is defined in [04-decay-and-ranking.md](04-decay-and-ranking.md).

## group — assemble a gathering

Proposes five people, drawn together into a tight cluster inside an animated
dashed hull; everyone else is pushed out and dimmed. The sheet names them,
explains *why* this group (*"Everyone already knows someone else here. The
quietest of them hasn't seen you in {span} — one table fixes five threads."*),
and lists each with how many of the others they know and how long since you saw
them. **RESHUFFLE** re-seeds from a random weak person. Confirming toasts a
drafted ping.

## time — scrub 18 months

A draggable scrubber over a 540-day window with tick marks and a play/pause
button that animates the graph backwards. Every link and node recomputes decay
against the scrub position, so you watch relationships thin, fray and fall apart
as the months undo themselves, and re-ignite as you scrub forward. Shows the
date, how long ago, and how many meet-ups fall within a week of that point.

## reach — v2

Zooms all the way out so the anonymous ghost cloud becomes the picture.

Three stats: **your people**, **anonymous friends-of-friends**, **total reach**.
A line reports how many of your 8x friends have shared their graph and how many
more people are one tap away. A comparison line pits your reach against the
best-connected friend. Then a list of every friend on 8x with their graph size
and reach, and a **PULL IN** button per row (**MERGED** once done).

## invites — v2

Incoming invitations show sender, place/time, who else is coming, and
Accept / Decline. Accepting writes a meet-up event dated today, re-ignites those
links, and toasts *"You're in."* Outgoing ones appear below at reduced opacity
showing **WAITING FOR THEM**.

There is no inbox metaphor on the graph itself: an incoming invitation makes the
sender's node breathe a dashed halo, and a pill under the wordmark reports the
count. **[design]**

## propose — v2

Reached from a focused person or an assembled group; **gated by the paywall**.
Selected people pull into a cluster, everyone else dims to 20%. Pick a day from
four chips (Tomorrow / Thursday / Sunday / Next week) and type a place. Sending
fires beams of light down the links to each invitee, one after another, and
toasts. The prototype simulates an acceptance ~3.8 s later, which flashes the
nodes and writes the meet-up. **[fixture]**

## pay — v2

The paywall, entered by attempting to propose while unsubscribed. Going live
sets the subscription, drops the lock glyphs, and resumes the interrupted
proposal. See [06-business-model.md](06-business-model.md).

## Design-time knobs

The prototype exposes these as tweakable props — useful as a list of the
parameters the real app will need to settle. **[built]**

| Prop | Section | Default | Range |
| --- | --- | --- | --- |
| `subscribed` | Business model | `false` | boolean |
| `decayHorizon` | Decay model | `240` days | 90–540, step 30 |
| `linkDecayStyle` | Decay model | `both` | `both` / `fragment` / `fade` |
| `showTrails` | Motion | `true` | boolean |
| `breathing` | Motion | `true` | boolean |
| `nodeLabels` | Motion | `smart` | `smart` / `always` / `never` |
