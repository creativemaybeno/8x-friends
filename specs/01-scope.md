# Scope

## Two iterations exist

| | Design page | Theme |
| --- | --- | --- |
| **v1** | `8x Friends v1 Offline-first.dc.html` | The graph, alone. No other users exist. |
| **v2** | `8x Friends v2 Social.dc.html` | v1 plus a social layer and the paywall. |

v1 was explicitly preserved so it can be returned to: **[brief]**

> Save this version as a v1 offline-first. I want to be able to go back to this
> version from the pages picker while you duplicate the page to work on new
> features and iterations.

**v2 is the current direction.** v1 is the fallback and is still a coherent,
shippable product on its own — which matters, because everything in v1 is free
forever under the business model (see [06](06-business-model.md)).

## v1 scope, as agreed

The user picked these explicitly from a scoping question: **[brief]**

- [x] Graph home — explore, pan/zoom, focus a person
- [x] Add a person + link them to others
- [x] Log a meetup (who, when, where)
- [x] Person detail / history / birthday
- [x] "Who to reach out to" nudges
- [x] Assemble a group to meet
- [x] Timeline / past meetups replay
- [ ] **Onboarding: import or enter first connections** — agreed in scope, but
      never designed. There is no onboarding surface in either prototype; both
      boot straight into a populated graph. **[open]**

Everything ticked exists as a working interaction in the prototype. **[built]**

## v2 scope, as agreed

From the v2 prompt: **[brief]**

- Add friends who also use the app; adding them merges **their whole friend
  graph, anonymised and faded out**
- A stat for how big your friend graph and friend-of-friends graph is / how many
  people you are connected to
- Easy comparison with others — "like how many friends you have"
- Inviting friends / meeting up sends a proposal/invitation notification, so you
  interact with friends through the app
- **This is the payment model.** Interacting with friends requires a
  subscription. Everyone can use the app and add people for free; organising a
  meet-up requires being a subscriber

All of it exists in the prototype. **[built]**

## Design decisions already locked

Picked explicitly during scoping — treat as decided: **[brief]**

| Question | Answer |
| --- | --- |
| Graph metaphor | Live force simulation, always gently breathing |
| Decay signal | Decay ring around the node **and** link fades/thins **and** link deconstructs, while fresh links pulse |
| What links mean | Friend-of-friend (who knows who), shared context (work, school, climbing gym), and how they met / who introduced them |
| Logging speed | **Ultra-fast: tap people on the graph, done** |
| Nudge style | Playful — the graph itself pulls at you |
| Home screen | Three variant directions, all built (WEB / ORBIT / STRATA) |

## Not in scope / not yet specified

Nothing here has been ruled out; it has simply never been decided. **[inferred]**

- Accounts, auth, identity — v2 assumes "friends who also use the app" but no
  sign-up, login or friend-discovery flow exists
- How an invitation is actually delivered (push, SMS, in-app only)
- Payments plumbing (App Store / Stripe), trial, cancellation, receipts
- Offline behaviour and sync conflicts — despite "offline" being in the name,
  it currently means *offline life*, not offline-capable software
- Contact import
- Data export / account deletion / GDPR surface
- Web or tablet layouts — phone only
- Anything multi-device

## Prototype fixture data

Both prototypes ship a seeded demo graph: 25 people including "You", 5 contexts,
50 explicit relationships, ~79 generated meet-up events over an 18-month window,
and (v2) 7 friends marked as 8x users. Names are Portuguese/European
placeholders. **[fixture]**

This is illustrative, not product. It is useful as a seed for local development
— see [03-data-model.md](03-data-model.md).
