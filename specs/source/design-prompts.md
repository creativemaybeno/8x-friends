# Source prompts

Every prompt written in the Claude Design project, verbatim. This file is
**provenance** — do not edit it. If a decision changes, change the spec that
cites it and retag, leaving this record intact.

Chat: *8x Friend Graph App Design* · started 2026-08-01 · 12 messages (7 from the user, 5 from Claude Design)

Extracted from the project transcript via `mcp__claude-design__get_conversation`.

## 1. Prompt

*message 0 · 2026-08-01 09:31:51 UTC*

> Create a design for 8x friend graph. The offline facebook.
>
> The idea is simple:
>
> 1. Enter your connections
> 2. Record when you met up with who when
> 3. Find out who to reach out to more again
>
> It should be a graph view of who you are friends with, how your friends and family and connected and related to each other and let you record your interactions with them, birthdays etc.
>
> Then it should suggest you who to hang out more again with, how to assemble a group to meet with etc.
>
> The central UI element should be a graph view showing the inter connections and every UI flow should be based on that.
>
> The focus for the UI design is **delightful animations**. Make the whole UI fluid and the graph move with the flow of the app. Zoom into the app, reassemble graph nodes, move them and make the links always move with the flow, etc.

> Message 1 is a verbatim duplicate of the prompt above (submitted twice).

## 2. Scoping answers

*message 2 · 2026-08-01 09:38:50 UTC*

> Questions answered:
> - platform: Mobile app (phone frame)
> - scope: Graph home (explore, pan/zoom, focus a person), Add a person + link them to others, Log a meetup (who, when, where), Person detail / history / birthday, "Who to reach out to" nudges, Assemble a group to meet, Timeline / past meetups replay, Onboarding: import or enter first connections
> - graph_metaphor: Live force simulation — always gently breathing
> - signal: A subtle decay ring / countdown around the node, Link fades / thins as time passes, Explore a few options, I think you can also make the link deconstruct/fall apart while the ones you interacted with recently pulse heavily or something like this so that your eye immediately falls onto the weak link
> - grouping: Friend-of-friend links (who knows who), Shared context (work, school, climbing gym), How they met / who introduced them
> - logging: Ultra-fast: tap people on the graph, done
> - nudges: Playful: the graph itself pulls at you
> - animation_focus: Graph re-layout when filtering / grouping, Link physics: springs, tension, settle, Time scrubbing: watch the graph decay/refresh, Entering the app: graph assembling from nothing
> - variations: Yes — 3 directions for the graph home screen
> - tone: Warm and human ("It's been a while since Ana")
> - name: 8x friends
> - references: Make the design modern and high-tech. A bit sci-fi. Closest reference: TRON: Legacy.

## 3. Prompt

*message 6 · 2026-08-01 10:17:51 UTC*

> Save this version as a v1 offline-frist. I want to be able to go back to this version from the pages picker while you duplicate the page to work on new features and iterations.
>
> The next iteration is: let's make it social. You can add friends who also use the app and adding them will add their whole friend graph but anonymized and faded out. This means you have a stat of how big your friend graph is and friend of friends graph / how many people you are connected to. And it will be easy to compare with others, like how many friends you have.
>
> And then inviting friends / meeting up with them will send a proposal/invitation notification. This way you can interact with your friends through the app. And this is the payment model: to interact with your friends in the app, you need to pay a subscription. This is the B2C business case. And everyone can use use the app and you can add people too when you are free, but to invite your friends / organize a date/meet up you have to be a subscriber.

## Non-prompt messages

These are UI-generated status pills from Claude Design's self-check, not
things the user typed. Listed for completeness:

- message 4: `Check didn’t complete`
- message 8: `Found issues — fixing…`
- message 10: `Found issues — fixing…`
