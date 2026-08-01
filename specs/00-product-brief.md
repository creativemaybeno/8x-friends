# Product brief

## What it is

**8x Friends — "the offline Facebook."** **[brief]**

A phone app for keeping the friendships you already have, rather than
accumulating new contacts. It holds a graph of the people in your life and how
they know each other, records when you actually met up, and tells you who is
slipping away.

The inversion of a social network: no feed, no posts, no follower counts. The
only content is *who you saw, and when*. Everything the app knows comes from you
having been somewhere with someone.

## The core loop

Three steps, in the user's own words: **[brief]**

1. **Enter your connections.**
2. **Record when you met up with who, when.**
3. **Find out who to reach out to more again.**

On top of that loop the app suggests who to see again, and helps assemble a
group worth gathering. **[brief]**

## The one non-negotiable UI decision

> The central UI element should be a graph view showing the interconnections and
> **every UI flow should be based on that.** **[brief]**

This is the product, not a visualisation of it. There are no screens stacked on
screens: every mode — focusing a person, logging a meetup, answering an
invitation, scrubbing through time — is the *same* force simulation re-forming
under different forces, so nothing ever cuts. **[design]**

Concretely, this means a feature that cannot be expressed as a change to the
graph is probably the wrong feature.

## The second non-negotiable: motion

> The focus for the UI design is **delightful animations**. Make the whole UI
> fluid and the graph move with the flow of the app. **[brief]**

Named animation priorities: **[brief]**

- Graph re-layout when filtering or grouping
- Link physics — springs, tension, settle
- Time scrubbing: watch the graph decay and refresh
- Entering the app: the graph assembling from nothing

The graph is always gently breathing, never static. **[brief]**

## Positioning and tone

| | |
| --- | --- |
| **Platform** | Mobile app, phone frame **[brief]** |
| **Visual direction** | Modern, high-tech, a bit sci-fi. Closest reference: *TRON: Legacy* **[brief]** |
| **Copy tone** | Warm and human — *"It's been a while since Ana"* **[brief]** |

The tension between those last two is deliberate and is the design's signature:
a cold, technical, near-monochrome interface whose *words* are gentle. Amber is
the only warm colour in the app, reserved for the relationships that are dying.
**[design]**

## Why the graph decays

The product's emotional engine. A relationship you have not fed visibly weakens:
the link thins, dims, lengthens — the person literally drifts away from you —
and finally breaks into drifting fragments while an amber ring empties around
their node. **[brief]** **[design]**

The user asked for exactly this:

> I think you can also make the link deconstruct/fall apart while the ones you
> interacted with recently pulse heavily or something like this so that your eye
> immediately falls onto the weak link **[brief]**

Nudges are therefore not notifications. **The graph itself pulls at you.**
**[brief]**

## Name

"8x friends" / "8x friend graph". **[brief]** The meaning of *8x* is not
recorded anywhere in the project. **[open]**
