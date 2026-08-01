# Design language

Direction: **modern, high-tech, a bit sci-fi. Closest reference: *TRON: Legacy*.**
**[brief]** Copy tone: **warm and human.** **[brief]**

That contrast is the signature. The chrome is cold, dark and technical; the
sentences are gentle. Do not warm up the interface, and do not let the copy go
clinical.

All values below are **[built]** — read directly out of the prototype.

## Palette

### Surfaces

| Token | Hex | Use |
| --- | --- | --- |
| Void | `#04070a` | App background |
| Page wash | `radial-gradient(1200px 700px at 22% -10%, #0a1a22, #04070a 62%)` | Behind the device |
| Sheet | `linear-gradient(#0b1a21f2, #060f14fa)` + `blur(18px)` | Every bottom sheet |
| Sheet (amber) | `linear-gradient(#1a130bf2, #0a0906fa)` | The nudge sheet only |
| Chrome bar | `rgba(10,22,28,.72)` | Toolbars, buttons |
| Nav bar | `rgba(7,16,21,.86)` + `blur(14px)` | Bottom nav |

Sheets are edged with `inset 0 0 0 1px rgba(125,231,247,.18)` and a hairline of
cyan gradient across the top.

### Ink

| Token | Hex | Use |
| --- | --- | --- |
| Cyan | `#7de7f7` | The brand. Wordmark, primary accents, live links |
| Cyan bright | `#9defff` | Highlights, scrub head, invitation halos |
| Cyan hover | `#bff4ff` | |
| Body | `#cfe9f2` | Default text |
| Heading | `#e6f8fd` / `#dff4fa` | Sheet titles, emphasis |
| Prose | `#9ac6d3` / `#8fb9c6` | Explanatory copy |
| Meta | `#5f93a3` | Mono labels, secondary values |
| Faint | `#4e7684` / `#3f6472` | Timestamps, dead text |
| On-accent | `#04121a` | Text on cyan buttons |

### Amber — use sparingly

`#FFB35C`. **The only warm colour in the app.** **[design]** Reserved
exclusively for decay and the nudge surface: dying links, emptying countdown
rings, the PULL tab. Its scarcity is what makes it work — the eye goes straight
to it. Never use it for a success state, a warning, or a brand accent.

### Context colours

Each shared context gets a node colour:

| Context | Hex |
| --- | --- |
| Family | `#8FD9FF` |
| Climbing | `#6FE3F5` |
| Work | `#9AA8FF` |
| University | `#7BF0C8` |
| Neighbourhood | `#C9A6FF` |

A node's fill is its context colour mixed toward `#0B1A21` by `0.15 + decay*0.66`
— so as a relationship fades the person drains into the background. Links mix
toward `#3E7E90`, then toward amber past `decay > 0.62`.

### Buttons

- Primary: `linear-gradient(#9defff, #4fd3ec)`, ink `#04121a`, glow `0 0 26px rgba(125,231,247,.3)`
- Amber primary: `linear-gradient(#ffd6a3, #ffb35c)`, ink `#1a1006`
- Secondary: transparent, `inset 0 0 0 1px rgba(125,231,247,.24)`, text `#a9dbe8`
- Disabled: flat `rgba(125,231,247,.14)` at 55% opacity

## Type

| Family | Weights | Use |
| --- | --- | --- |
| **Chakra Petch** | 300–700 | Everything human — names, headings, body, buttons |
| **JetBrains Mono** | 300–500 | Everything machine — section labels, timestamps, stats, hints |

The mono/sans split *is* the information architecture: mono means the app is
reporting a fact, sans means it is talking to you. Mono labels are uppercase,
8.5–9.5 px, letter-spaced `.14em`–`.2em`.

Scale: 26–27 px sheet titles · 19–22 px subject names · 16 px input ·
12.5–13.5 px prose · 10.5–11.5 px secondary · 8–9.5 px mono labels.

## Motion

Ambient, always running: **[built]**

| Effect | Timing |
| --- | --- |
| `scan` — a cyan scanline sweeping the screen | 9 s linear, infinite, 40% opacity |
| `bootpulse` — the unread dot | 2.2 s ease-in-out |
| `flicker` — the wordmark on boot | 3.4 s ease-in-out |
| Node breathing | `sin(t * 0.62 + phase)`, per-node phase offset |
| Light packets along fresh links | Speed scales with freshness |

Transitions: sheets `.55–.62s cubic-bezier(.16,1,.3,1)` (a firm overshoot-free
settle), camera lerps at `0.075–0.085` per frame, node dimming at `0.09`,
selection at `0.16`.

**The rule underneath all of it:** every mode change is the same simulation under
different forces. Nothing cuts, nothing fades to black, nothing pushes a new
screen. If a change cannot be expressed as a force, it does not belong.

## Device frame

Phone only. `402 × 874` — an iPhone-class frame in dark mode, with dynamic
island, status bar and home indicator, rendered by `ios-frame.jsx` in the
Claude Design project (a reusable iOS 26 "Liquid Glass" component). **[built]**

Layout inside the frame: chrome overlays float above the graph, which fills the
whole surface; everything else arrives as a bottom sheet at `translateY(112%)`
→ `0`. The graph is never covered more than about half.

## Porting to Flutter **[inferred]**

Some notes for when this becomes real:

- The graph is a hand-written force simulation drawing to SVG. In Flutter this
  is a `CustomPainter` on a `Ticker` — do not reach for a widget-per-node.
- The `blur(14–18px)` sheets map to `BackdropFilter`; it is expensive on older
  Android, so consider a flat fallback.
- Chakra Petch and JetBrains Mono are both on Google Fonts.
- `mixHex(a, b, t)` in the prototype is plain RGB lerp — `Color.lerp` matches.
- Everything is dark-mode only. There is no light theme and nothing suggests one
  is wanted.
