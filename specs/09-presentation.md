# 8x Friends — final hackathon pitch

## Purpose

This is the final, jury-facing pitch for 8x Friends. It is the product story
we will demonstrate live, and the source of truth for deciding which features
are worth developing for the hackathon.

**Audience:** a hackathon jury evaluating design and B2C potential.

**Product promise:**

> **8x Friends helps you keep the friendships that matter from quietly fading
> away.**

It does the remembering and the assembling: it notices a valued relationship
quietly fading, reveals the people who can naturally reconnect the circle, and
turns that insight into a low-friction real-world plan.

This is not a messaging app, a social feed, or a contact collector. It is a
living private graph of real relationships, made useful by helping people meet
in real life.

## The jury story

The live demo uses two phones and two real demo accounts: **Calvin** and
**Yassie**. Hannan is a third person already visible in the network.

1. **Calvin opens 8x Friends.**

   He sees the global graph of people in his life. Relationships he meets with
   frequently are visually primary; neglected relationships are quieter and
   visibly fading. Calvin's connection to Yassie has faded because they have
   not seen each other in months—not because either person stopped caring, but
   because life got busy and neither initiated.

2. **Calvin focuses Yassie.**

   Tapping Yassie's node reveals her name, the time since they last met, a
   simple relationship-health signal, and two actions:

   - **Plan something**
   - **Log a meetup**

   Calvin chooses **Plan something**, selects a simple preset time such as
   Saturday at 7 PM, and sends Yassie an invitation.

3. **Yassie receives a real notification.**

   On her separate phone, a notification lets Yassie open the invitation. She
   can accept it or propose a different day or time. In the demo, she accepts
   Calvin's proposed time.

4. **Yassie grows the plan through her circle.**

   After accepting, Yassie is offered **Add friends from your circle**. She
   chooses Hannan. The invitation is sent automatically to Hannan; Yassie does
   not need Calvin's approval to add him.

   The full graph remains visible throughout. Calvin, Yassie, and Hannan form
   a foreground planned cluster, while everyone else remains part of the same
   global graph. Hannan appears with a dimmed node, a subtle pending ring, and
   a dashed plan connection.

5. **Hannan joins.**

   Hannan's acceptance happens automatically in the background after a short
   delay. His pending ring resolves, the planned cluster becomes fully bright,
   and the planned meetup is visible from an icon on each attendee's graph
   node. Tapping that icon shows the plan details.

6. **The plan becomes a real meetup.**

   The product sends no pre-meetup reminder. On the morning after the planned
   meetup, each attendee receives a notification asking whether it happened.
   For the live demo, a clearly labeled demo-state control advances the plan to
   that moment and triggers the real notification flow.

   Once confirmed, every existing direct relationship pair among the attendees
   is strengthened. The app shows a brief **Connection renewed** popup while
   the affected links become brighter, thicker, and more prominent in the
   graph. The graph then settles back into its full, living state.

7. **Calvin makes a new direct connection.**

   Calvin can see Hannan as an indirect connection through Yassie. He sends
   Hannan a consent-based connection request. A few seconds later Hannan
   accepts in the background, and the jury sees a new bright direct
   Calvin–Hannan edge animate into the graph.

   This edge starts at neutral health. A connection request creates a
   permissioned direct connection; meeting and logging time together is what
   builds relationship health.

## What the graph means

The graph is always global: it is the product's primary interface, rather than
a visualisation hidden behind separate screens.

- **Relationship-health view:** the default view. Recent, frequent real-world
  meetups make people and links more primary. Relationships fade as time passes
  without meeting; expected frequency is personalized by the relationship's
  observed pattern, rather than using one global cadence.
- **Physical-distance view:** an alternate view for finding people nearby for
  spontaneous plans. It requires opt-in location permission. A person's
  approximate distance updates only when they open the app; 8x Friends must
  never present exact live locations or location history.
- **Circle:** an unlabeled, real-world network of people who have met. Direct
  edges represent known/consented relationships; people beyond a direct edge
  are indirect connections through mutual friends.
- **Planned meetup:** an upcoming plan is represented by an icon on the
  relevant people in the graph, not a separate card-first interface.

## Consent and privacy

Trust is fundamental to the B2C product story.

- A person may send a direct connection request only to an indirect connection
  visible through a mutual friend—never to a stranger via search.
- The recipient must explicitly accept before a new direct edge exists.
- Before accepting, the requester sees only the minimum necessary: the
  person's name, neutral avatar/initial, and the mutual connection. They do
  not see activity, relationship health, location, or a broader friend graph.
- Accepting a direct connection never reveals either person's entire graph;
  only the direct relationship and mutually visible people are exposed.
- Attendance at a group meetup does **not** automatically create direct
  friendships between every attendee. New direct relationships require a
  consent-based request.

## Features required for the hackathon demo

### Must build

- Two distinct demo accounts on separate phones: Calvin and Yassie
- A global animated social graph with pre-populated demo data
- Relationship-health visual hierarchy, including a clearly fading
  Calvin–Yassie connection
- Person focus state with relationship context and **Plan something** / **Log a
  meetup** actions
- Time proposal, invitation sending, and a real device notification
- Invitation acceptance and an option to propose an alternate time
- Add-from-circle flow after accepting an invitation
- Pending attendee state and delayed automatic acceptance for Hannan
- Planned-cluster graph animation that preserves the visible global graph
- Upcoming-plan icons on participant nodes and plan-detail access
- Demo-state advance to the next morning, followed by a real confirmation
  notification
- Confirmation flow, **Connection renewed** popup, and link-strengthening
  animation
- Indirect-connection discovery, consent-based direct connection request, and
  delayed acceptance that creates a neutral direct edge
- Physical-distance graph view with opt-in location permission and
  app-open-only location updates

### Should build if time permits

- Manual meetup logging: select attendees and a date, defaulting to today
- In-plan cancellation and rescheduling
- One lightweight consensus view when an attendee proposes a new time
- Coarse distance labels such as nearby, same city, and far away

### Explicitly out of scope for the pitch/demo

- Contact import and new-person onboarding
- Search and stranger discovery
- Social feeds, posts, likes, follower counts, chat, and activity histories
- Calendar integration or availability matching
- Exact or continuous location tracking
- Pre-meetup reminder notifications
- Full authentication, billing, subscription management, and freemium gates
- Third-device interaction for Hannan; his delayed acceptance is simulated
- Complex decline handling and invitation edge cases

## Why this wins on design

The demo is designed around a single transformation the jury can see:

```text
fading friendship → a real invitation → a small group plan
→ a real meetup → a renewed relationship → a consented new connection
```

Every important state change happens where the product lives: in the graph.
The graph gathers people for an upcoming plan, shows uncertainty while someone
is pending, visibly renews a relationship after a real meetup, and grows only
when people consent to connect. That makes the interaction feel less like
managing contacts and more like caring for a real social world.

## B2C framing

8x Friends is a **freemium B2C product**. Pricing is not part of this demo;
the pitch leads with the immediate personal value of preserving friendships.
The future paid layer can offer deeper planning and insights, while the core
loop—notice, reach out, meet, renew—remains the reason people return.
