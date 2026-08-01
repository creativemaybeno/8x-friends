# 8x Friends — stage script

Runtime ~3 min. One screen, no navigation. Every mode is the same simulation
under different forces. Read this cold and you can run the demo.

Thesis to land: **relationships decay unless you maintain them.** This app makes
that physical — people you neglect literally drift away, and meeting them pulls
them back in.

---

## 1. Cold open — the graph assembles

- **Do:** Launch the app. Say nothing for ~3 seconds.
- **See:** Black screen, `8x` / `assembling your graph`, then nodes fly out and
  settle. Links breathe; bright ones carry travelling packet dots, faded ones
  fray into drifting dashes. Header reads `{n} PEOPLE · {n} ANON · {n} IN REACH`.
- **Say:** "This is my life, drawn as a graph. Every line is a real relationship,
  and every line is dying a little bit right now."

## 2. WEB → ORBIT

- **Do:** Tap `ORBIT` in the top segmented control. Do not cut away — let it
  re-form.
- **See:** The same nodes swing out onto guide rings. Hint line changes to
  `RADIUS = TIME SINCE YOU MET`.
- **Say:** "Same simulation, different force. Distance from me is now literally
  time since I last saw you — the far ring is people I'm losing."

## 3. ORBIT → STRATA → back to WEB

- **Do:** Tap `STRATA`, hold 3 seconds, tap `WEB`.
- **See:** Five labelled islands — `FAMILY`, `CLIMBING`, `WORK`, `UNIVERSITY`,
  `NEIGHBOURHOOD` — then everything collapses back into the free web.
- **Say:** "Or cluster by shared context. Nothing re-renders, nothing reloads —
  I'm just changing what the graph is pulled by."

## 4. Focus a person

- **Do:** Tap a bright, close node near the centre.
- **See:** Camera pushes in, neighbours pull close, everyone else dims. The focus
  sheet rises: name, `LAST TOGETHER`, `BIRTHDAY`, `SIGNAL STRENGTH {n}%`, a
  signal bar, `SHARED HISTORY`, and a line about the state of the thread.
- **Say:** "Tap anyone and you get the truth about that thread — when we were
  last together, how strong the signal is, who we both know."

## 5. The nudge list — the emotional beat

- **Do:** Tap `PULL` in the bottom nav (amber, with the pulsing dot).
- **See:** Camera pulls way back. Three neglected people stretch out on elastic
  tethers, everyone else dims. Sheet: `THE GRAPH IS PULLING AT YOU`, rows with a
  group line and a big `{n}d` number.
- **Say:** "The graph nominates. These are people I'm close to and haven't seen —
  this one for over a year. Nobody told me. The graph did."

## 6. The money shot — WE MET UP

- **Do:** Tap `WE MET UP` on the top nudge row. Then tap two or three more people
  on the graph. Then hit the confirm button (`LOG {n} PEOPLE`).
- **See:** Selected nodes ring up and pull to the centre. On confirm: the sheet
  drops, the links to those people **re-ignite** — thick, bright, packets running
  again — the node rings refill, and a toast reads `{Name} is lit up again.`
  Tap `PULL` again: **the list has reordered**; that person is gone from it.
- **Say:** "I saw them on Sunday. That's the whole interaction — one tap on who
  was there. Watch the thread come back to life. That's not a database row
  changing colour, that's the force simulation re-tightening."

## 7. Time scrubber — 540 days in one drag

- **Do:** Tap `TIME`. Drag the handle slowly all the way left, then release it
  back to `TODAY`.
- **See:** `{n} LINKS ALIVE` counts down. Links thin, fray, break; nodes drift
  outward; the one you just logged goes dark as you pass its date, and re-ignites
  on the way home.
- **Say:** "Decay is never stored — it's a pure function of dates. So I can
  recompute any day in the last eighteen months, including the meet-up I logged
  thirty seconds ago."

## 8. The group assembler

- **Do:** Tap `GROUP`.
- **See:** Five people pull into a tight cluster with a dashed marching-ants hull
  around them. Sheet: `ASSEMBLED FROM THE GRAPH`, the title `{A}, {B}, {C} and
  {D}`, a why-line, and each row's `knows {n} of them`.
- **Say:** "And when it's five threads at once, it assembles the table for you —
  people who already know each other, weighted by who I'm losing fastest. One
  dinner fixes five relationships."

## 9. Reshuffle once

- **Do:** Tap `RESHUFFLE`. Once. Not twice.
- **See:** A different five snap into the hull.
- **Say:** "Don't like it? It'll find you another five."

## 10. Close on the thesis

- **Do:** Tap `GRAPH` to go home. Let it breathe.
- **See:** The full web, alive, the freshly-lit thread obviously brighter than
  the rest.
- **Say:** "Every social app optimises for how many people you can reach. This
  one optimises for how few you're losing. Your graph never leaves your phone —
  the only thing that goes out is the invitation."

---

## PRE-FLIGHT

Do all of this **before** you are on stage. Not from the podium.

1. **Run the app once on the demo device, on any network.** `google_fonts`
   downloads Chakra Petch and JetBrains Mono at first launch and caches them.
   A cold cache on venue Wi-Fi means the whole app renders in fallback fonts and
   looks wrong. This is the single most likely visible failure.
2. **Check `app/dart_define.json` points at the live project** —
   `https://<your-project-ref>.supabase.co` and an `sb_publishable_` key.
   The file is gitignored, so a fresh checkout has no backend and boots to an
   amber error line.
3. **Smoke-test the backend:** anonymous signup must return an access token
   (see `docs/deploy.md` §3). If it returns `anonymous_provider_disabled`, the
   app cannot boot at all.
4. **Simulator already booted, app already launched, graph already assembled**
   before you walk on. Reseed from the wordmark if you want a clean start.
5. **Kill notifications / Do Not Disturb** on the demo machine.
6. Run the demo once end to end, then reseed.

## THE PANIC BUTTON

**Long-press the `8x` wordmark, top left.** Wipes and regenerates the whole
graph from scratch, resets the time scrubber to today, and drops you at `GRAPH`.
Toast: `Graph reseeded.`

Use it when:

- you logged a meet-up in rehearsal and the nudge list is now boring;
- you dragged the time scrubber and the graph looks wrong;
- anything is in a state you don't recognise and you have ten seconds.

Do **not** use it mid-story — it takes a moment and it re-randomises the fixture,
so the person you were about to point at may not be there. Reseed between runs,
never during one.

## WHAT IS FRAGILE

Be honest with yourself about these; each has a recovery.

- **Fonts.** Cold `google_fonts` cache → fallback fonts, everything looks off.
  Fix: pre-flight step 1. No live recovery.
- **Network at boot.** The app signs in anonymously and loads the graph before it
  shows anything. Bad venue Wi-Fi = long black boot screen or an amber error
  under the `8x` wordmark. Fix: launch **before** you go on and don't kill the
  app. Have a phone hotspot ready.
- **The fixture is random.** Names, groups and neglect ages differ every reseed.
  Never script a specific name — say "this one", point at the screen. Check the
  top nudge row is genuinely dramatic (ideally 300+ days) before you start; if
  it isn't, reseed.
- **Tap targets are small.** Nodes are ~10–14 px and they move. Zoom or pause the
  breathing before tapping in step 6; a missed tap deselects. Tap slowly.
- **Step 6 is the demo.** If the re-ignite doesn't read from the back of the
  room, narrate it and immediately re-open `PULL` to show the reordered list —
  the list change is the unambiguous proof.
- **The time scrubber under load.** Dragging fast recomputes decay for every
  link every frame. Drag *slowly*; it also looks better.
- **`PROPOSE` / `REACH` / paywall.** These touch the network and the subscription
  flag mid-demo. They are not in the spine above. Don't go there unless asked,
  and if asked, know that `PROPOSE` bounces you to the paywall sheet first.

## WHAT IS NOT IN v0

Say these plainly if asked; don't get caught pretending.

- No editing or deleting — you can add people and log meet-ups, nothing else.
- No contact import. Every person is entered by hand.
- No push notifications. The graph pulls at you inside the app, not on your
  lock screen.
- No real billing. `GO LIVE` flips a boolean; there is no payment processor.
- Group size is always five. It is not configurable.
