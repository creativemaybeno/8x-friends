# The social layer (v2)

> Let's make it social. You can add friends who also use the app and adding them
> will add their whole friend graph but anonymized and faded out. This means you
> have a stat of how big your friend graph is and friend of friends graph / how
> many people you are connected to. And it will be easy to compare with others,
> like how many friends you have. **[brief]**

## Merging a graph

Friends who are also on 8x can share their graph into yours. Merging sprays
their people out of their node as dim, nameless **ghosts**. **[design]**

The rule that makes this acceptable: **you get the count, never the names.**
**[design]** A ghost has no name, no initials, no label — it is a small dim
circle with a dotted tether to the friend who introduced it.

### The de-duplication moment

When a ghost corresponds to someone you *already know*, it does not stay a
ghost. It flies into your existing node, pops, and the node flashes white — the
graph visibly de-duplicates itself in front of you. **[design]** **[built]**

This is the layer's signature animation and it does double duty: it is delightful,
and it silently tells you "you two have a mutual friend" without naming anyone.

### Merge mechanics **[built]**

Each 8x friend has a graph of 6–10 ghosts, staggered in ~70 ms apart. Roughly
60% of them are marked as shared with someone you already know and dissolve
about 1.5 s after appearing. Ghosts repel each other ~2.7× more weakly than real
people, so they cloud rather than spread, and their tethers are short and stiff
so they hug their owner.

Ghosts are dimmed to 22% normally, 70% in `reach` mode, and 10% when you focus
someone — they are ambient texture, never the subject.

One friend's graph (`tomas`) is pre-merged at boot so the concept is visible
immediately rather than requiring discovery. **[fixture]**

## Reach — the stat

Three numbers, shown in `reach`: **[built]**

| Stat | Meaning |
| --- | --- |
| **your people** | Real people you have entered |
| **anon** | Anonymous friends-of-friends currently merged |
| **in reach** | The sum — the headline number |

Also shown live in the home hint line: `N PEOPLE · N ANON · N IN REACH`.

The comparison the brief asked for is one line: *"{name} reaches {N}. You reach
{M}."* against your best-connected friend. **[built]** Each row in the friend
list shows *"{N} people · reaches {M}"*.

This is the product's one competitive/vanity surface, and it is deliberately
about **reach**, not friend count — which keeps it pointed at the thing the app
is for. **[inferred]**

## Invitations

> Inviting friends / meeting up with them will send a proposal/invitation
> notification. This way you can interact with your friends through the app.
> **[brief]**

**Invitations live on the nodes. No inbox metaphor, no feed.** **[design]**

- An **incoming** invitation makes the sender's node breathe a fast dashed halo
  (`#9DEFFF`, 3.4 rad/s)
- An **outgoing** one gives each invitee a slower, sparser dashed ring
- **Sending** fires beams of light down the links to each person in turn, ~130 ms
  apart **[built]**
- A pill under the wordmark reports how many invitations are waiting

Accepting writes a meet-up event dated today, re-ignites those links, flashes the
nodes and toasts *"You're in. {place}."* So the social layer feeds the same event
log the offline app runs on — **there is only one source of truth.** **[built]**

## Privacy posture

Assembled from what the design does rather than from an explicit statement, so
treat it as a description, not a policy: **[inferred]**

- Merging shares **structure and counts, not identities**
- Ghosts are never named, never labelled, never tappable to reveal
- De-duplication reveals *that* you share someone, never *who*
- Nothing indicates whether merging is symmetric, revocable, or requires the
  friend's consent per-merge. **[open]**
- Nothing indicates what the *other* person learns when you merge them. **[open]**

These are the questions a privacy review will ask first, and none of them have
answers yet. Given the product's whole premise is a private record of your real
relationships, getting this wrong is the most expensive mistake available.

## What is missing before this can ship **[inferred]**

- Friend discovery — how you find out a friend is on 8x at all
- Consent and revocation for graph sharing
- Whether ghost data ever leaves the friend's device/account, or the server only
  returns aggregate counts
- Invitation delivery outside the app (push, SMS) for people who are not looking
  at their graph
- What happens to an invitation whose sender cancels, or that nobody answers
