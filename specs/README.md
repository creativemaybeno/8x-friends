# 8x Friends — product specs

Everything currently known about the product, reconstructed from the Claude
Design project *8x Friends: Offline Facebook* and the prompts written in it.

## Read in this order

| File | What it covers |
| --- | --- |
| [00-product-brief.md](00-product-brief.md) | What the product is, the core loop, positioning, tone |
| [01-scope.md](01-scope.md) | v1 / v2 scope, what is designed vs. only agreed, non-goals |
| [02-features.md](02-features.md) | Every mode of the app, in detail |
| [03-data-model.md](03-data-model.md) | Entities and fields, and a proposed Postgres shape |
| [04-decay-and-ranking.md](04-decay-and-ranking.md) | The decay maths, nudge ranking, group assembler |
| [05-social-layer.md](05-social-layer.md) | Graph merging, anonymity, invitations |
| [06-business-model.md](06-business-model.md) | What is free, what is paid, and why |
| [07-design-language.md](07-design-language.md) | Palette, type, motion principles, device frame |
| [08-open-questions.md](08-open-questions.md) | Decisions still to make |
| [source/design-prompts.md](source/design-prompts.md) | The original prompts, verbatim |

## How to read the provenance markers

These specs were reconstructed, not authored from scratch, so every non-obvious
claim is tagged with where it came from. **Check the tag before you treat
something as decided:**

| Tag | Means |
| --- | --- |
| **[brief]** | Stated directly in a prompt. Decided — change only deliberately. |
| **[design]** | Asserted in the narrative panel of a design page. Proposed by Claude Design and left standing, but never explicitly confirmed. |
| **[built]** | Observed in the prototype code. Describes what the prototype does, which is not automatically what the product should do. |
| **[fixture]** | Demo data in the prototype. Illustrative only. |
| **[open]** | Explicitly unresolved. |
| **[inferred]** | Not in any source — reconstruction filling a gap. Treat as a suggestion. |

## Iterating on these

The specs are the product's source of truth; `design/files/` is the visual
source of truth. They are separate on purpose — a design can be re-rendered, a
decision cannot.

- Edit these files directly and commit. They are plain Markdown, no tooling.
- When a change lands here that the designs should reflect, say so in the
  Claude Design chat and re-run `/design:pull` afterwards
  (see [design/README.md](../design/README.md)).
- When you change something tagged **[brief]** or **[design]**, retag it —
  a spec whose provenance has gone stale is worse than one with none.
- New decisions that were never in the design project get no tag; they are
  yours.

## What is not here

- **Anything about how the app is built.** No architecture, schema migrations or
  API design decisions have been made yet — the Postgres sketch in
  [03-data-model.md](03-data-model.md) is explicitly a proposal.
- **Onboarding.** It is in scope but was never designed. See
  [01-scope.md](01-scope.md).
- **Auth, notification delivery, offline sync, payments plumbing.** Implied by
  the product but never specified. Listed in
  [08-open-questions.md](08-open-questions.md).
