# Business model

> This is the payment model: to interact with your friends in the app, you need
> to pay a subscription. This is the B2C business case. And everyone can use the
> app and you can add people too when you are free, but to invite your friends /
> organize a date/meet up you have to be a subscriber. **[brief]**

## The split

**Memory is free. Motion costs.** **[design]**

| Free, forever | Requires subscription |
| --- | --- |
| The graph — add people, link them | **Propose a date** |
| Log meet-ups | **Ping a group** |
| Birthdays, person detail, shared history | |
| Nudges — who to reach out to | |
| Group assembler (seeing the suggestion) | |
| Time scrubbing | |
| Merging other people's graphs | |
| Reach stats and comparison | |
| **Answering an invitation** | |

Everything that keeps your own record stays free, which is what protects the
"offline Facebook" promise — the entire v1 product is free forever. You pay only
at the moment you reach *through* the app to someone else. **[design]**

## Answering is free — deliberately

The one call worth defending: **[design]**

> Charging both sides would stall the network before it starts — a free user who
> keeps getting invited is the best possible lead.

A non-subscriber who is invited repeatedly experiences the paid product's value
without paying, and the natural next step is wanting to invite back — which is
the paywall. This makes invitations the growth loop *and* the conversion
mechanism at once.

The design offers a **both-sides-pay variant** if wanted. Not built. **[open]**

## Price

**8x Live — €4/month.** **[design]**

Flagged clearly: the price came from the design's own proposal, not from any
prompt. **The user never specified an amount.** Treat €4 as a placeholder that
happens to be rendered in the mockup. **[open]**

## How the paywall behaves **[built]**

It is not a wall you hit before doing anything — it is *interruption at the
moment of intent*, which is why it converts:

1. You focus a person or assemble a group and tap **PROPOSE**
2. If unsubscribed, the app enters `pay` — camera pulls back, paywall sheet rises
3. On going live, the lock glyphs and paywall drop away and **the interrupted
   proposal resumes automatically** with your selection intact

That last step matters: the user is returned to exactly what they were trying to
do, not dumped on a home screen.

A `LIVE` / `OFFLINE` status indicator reflects the subscription state, and lock
glyphs mark gated actions before you try them.

## Not specified **[inferred]**

None of the commercial plumbing exists:

- App Store / Play billing vs. Stripe — and the platform-fee implications of
  billing outside the stores
- Trial, grace period, annual pricing, regional pricing
- What happens to *pending outgoing invitations* when a subscription lapses
- Whether a lapsed subscriber's past invitations remain visible to recipients
- Refunds, cancellation, dunning
- Whether "everyone can use the app" means no account at all until you subscribe,
  or an account with a free tier — this affects the whole auth design
