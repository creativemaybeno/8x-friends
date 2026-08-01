# Open questions

## Asked by the design, still unanswered

These were put to the user in both v1 and v2 and never answered. **[open]**

**[updated]**: manual answers inserted after

1. **Should decay speed be per-person** — you see your sister weekly, a uni
   friend twice a year — **rather than one global horizon?**

   Probably the highest-value question here. One global 240-day horizon means the
   nudge list is dominated by people you were never going to see often. The
   `closeness` field (1–3) already exists and partly compensates, but it is
   coarse and the user can't edit it. Options: derive a per-person cadence from
   observed history, or let the user set "I want to see this person every ~N
   weeks".

   Answer: this should be solved algorithmically, where the app automatically detects
   how often you are seeing this person based on your shared history and behavior.
   If this person has a connection to a connection of you who you see very often, you
   are more likely to see that other person often too, and so on.

2. **Does the group assembler need a "when"** — pulling in calendar free time —
   **or stay a pure graph suggestion?**

   Currently it names five people and stops. Adding time turns it into a
   scheduling product with all the integration weight that implies.

   Answer: stay with pure graph suggestions.

3. **Onboarding: import contacts, or is hand-entering the first 20 people part of
   the ritual?**

   Unresolved *and* undesigned — there is no onboarding surface at all. The
   product does nothing until a graph exists, so this is on the critical path to
   anything shippable.

4. **Both-sides-pay?** The design proposed that only the sender pays and offered
   to show a variant where both do. Not built.

   Answer: only the sender / person who invites pays, as in assembling a group is
   a premium feature. But don't bake this in hard. This is still up for decision.

## Decided by the design, never confirmed by you

Standing because nobody objected, not because anyone agreed. **[design]**

- **€4/month** for 8x Live. The prompt said "a subscription", never a price.
  - Answer: suggestion is good for now.
- **"Memory is free, motion costs"** as the free/paid boundary.
  - Answer: Stale is free, live costs.
- **Answering an invitation is free.**
  - Answer: yes.
- **Amber as the sole warm colour**, reserved for decay.
  - Answer: the design is still up to change entirely. Write the code so the design can be easily changed. And I mean _everything_ can be changed from the ground up when it comes to the design. Focus on getting the functionality (graphs, relations, etc.) correct and do not bake the design into the code decisions.

## Never raised anywhere

Implied by the product but absent from every source. **[inferred]**

### Blocking a real build

- **Accounts and auth.** v2 assumes "friends who also use the app" with no
  sign-up, login, or friend-discovery flow.
  - Answer: We go for anonymous auth because that is all we need. You get assigned an anonymous account when you first open the app and must enter your name.
- **Consent for graph merging.** Is it symmetric? Revocable? Does the other
  person know? Does their data leave their account, or does the server return
  only counts? The whole premise is a private record of real relationships, so
  this is the most expensive thing to get wrong.
  - Answer: Keep any connections that are not shared anonymous (do not show a name / just a ghost). For shared connections, show their real name. The way to make it work is to connect account IDs to everyone you are connected to and only share those. If you are not connected to another account ID, you do not see their name. That's it. This makes it only semi private because you can make conclusions based on anonymous connections too. But that's okay. This is a hackathon project only.
- **Invitation delivery** outside the app, for people not currently looking at
  their graph.
  - Answer: we do app-only for now to keep it doable for the presentation.
- **What "offline" means technically.** The name says offline; the product is a
  network app. Is the graph usable on a plane? What syncs, and what happens on
  conflict?
  - Answer: Offline means there is no ads and no content in the app, you do not have a feed. It's just about the real-life connections.

### Product shape

- **Contexts are a fixed 5-value enum and a person has exactly one.** Real people
  belong to several circles. Almost certainly needs to become user-defined tags,
  many-to-many.
- **`closeness` is invisible.** It drives node size and nudge ranking but the
  user can never see or set it.
- **Logging drops the place.** Scope said "who, when, where"; the flow only asks
  who and when, and stores `"you logged this"`.
- **Group size is hardcoded to five.**
- **Events without you.** The model supports meet-ups among your friends that you
  weren't at — that's what powers *"{name} saw them more recently"* — but nothing
  says where that information comes from.
- **Birthdays are stored but nothing happens on them.** No reminder, no surfacing.
- **No delete/edit.** You can add a person and log a meetup; you cannot correct
  or remove either.

### Commercial

- Store billing vs. Stripe; trials, annual pricing, regional pricing
- What happens to pending outgoing invitations when a subscription lapses
- Whether the free tier requires an account at all

### Legal / trust

- Data export, account deletion, GDPR surface
- The app holds a detailed private social graph of people who never consented to
  being in it — including their birthdays. That is a real exposure and nothing in
  the project addresses it.

## Suggested order

If you only resolve a few before building:

1. Onboarding (#3) — nothing works without a graph
2. Consent model for merging — it constrains the schema
3. Per-person decay (#1) — it changes the core loop's quality
4. Accounts/auth — it constrains everything else
