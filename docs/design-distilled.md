# Design distilled — 8x Friends (v1 + v2 prototypes)

Source: Claude Design files `8x Friends v1 Offline-first.dc.html`, `8x Friends v2 Social.dc.html`.
v2 is a superset of v1; differences are called out. Excluded by instruction: decay/signal
formulas, horizon 240, nudge/group scores, palette hexes, dim %, fonts, sheet anim, spring rest length.

## 1. Force simulation constants

One loop per rAF (no sub-ticks, no alpha decay — the sim never cools). Integration is
`v *= damping; pos += v` per frame. Constants:

| Thing | Value |
| --- | --- |
| Repulsion (all pairs, O(n²)) | `f = 2100 / d²`, clamped `f ≤ 3`; ghost pair (v2, either node ghost): `780 / d²` |
| Min separation guard | if `d² < 4` → randomize direction, treat `d² = 4` |
| Spring stiffness (real link) | `k = 0.0085 * (1.25 - dec*0.75)`; force `= (d - rest) * k` |
| Spring stiffness (ghost link, v2) | `k = 0.02`, rest `= 34 + b.r*2` |
| Damping / friction | `v *= 0.865` every frame (both axes, all nodes) |
| Boot slow-motion | position step multiplied by `0.35` while `mode === 'boot'` |
| "Me" centring | `v += -pos * 0.06` |
| Global weak centring (non-me) | `v += -pos * 0.0016` |
| Breathing jitter force | `vx += sin(t*0.62 + phase)*0.035`, `vy += cos(t*0.55 + phase*1.7)*0.035` (skipped when pinned; toggle `breathing`) |
| Radial helper `pullR(n, target, k)` | `f = (|pos| - target)*k`; `v -= f * pos/|pos|` |
| Max velocity clamp | none (only the `f ≤ 3` repulsion clamp) |
| Node radius | me: `17`; others: `7 + close*2.4` (close ∈ 1..3 → 9.4 / 11.8 / 14.2); newly added node: `9.4`; ghost: `4.2 + rand*2.6` |
| Smoothing lerps | dim `0.09`, decay `0.1`, selection `selP` `0.16`, ghost dim `0.09`, ghost merge-in `0.17` |
| Appear ramp | `appear = clamp((t - born)/0.7)`, eased `1-(1-a)³`; born stagger `0.25 + i*0.055` s |
| Boot fade | `bootF = clamp((t-0.5)/1.6)`; boot screen auto-dismisses after 2600 ms |
| Node phase | `rand * 6.28` |

Layout anchors (STRATA): 5 group anchors on a circle radius `205`, angle `i/n*2π - π/2`.

## 2. WEB / ORBIT / STRATA as force configs

Same simulation, same repulsion + springs + damping. Only the "home force" differs, and only
in modes `home`, `boot`, `add` (all other modes override with their own radial force):

- **WEB** — free layout. Only weak centring `v += -pos * 0.0016`. Nothing else on.
- **ORBIT** — radial: `pullR(n, 104 + dec*250, 0.012)`. Radius = decay, i.e. time since you met.
  Weak centring off. Guide rings drawn at r = 110, 190, 275, 355 (dashed `2 7`, opacity 1 only
  in orbit + home/boot).
- **STRATA** — anchor attraction to the node's group anchor: `v += (A - pos) * 0.016`. Not
  y-bands — it's 5 islands on a circle of radius 205. Weak centring off. Group labels drawn at
  `A * 1.34`, y-offset `-18` if `A.y < 0` else `+26`, only in strata + home.

Mode force overrides (all via `pullR`):

| Mode | Force |
| --- | --- |
| focus | focus node `v += -pos*0.09`; neighbours `pullR(124, 0.012)`; rest `pullR(330, 0.008)` |
| nudge | nudged `pullR(296 + sin(t*2.2+phase)*30, 0.022)` (elastic tether) |
| group | members `pullR(86, 0.02)`; others `pullR(330, 0.01)` |
| log | selected `pullR(66, 0.026)`; others none |
| propose (v2) | selected `pullR(92, 0.024)` |
| add | none (weak centring applies) |
| reach (v2) | none; ghosts brighten |

## 3. Camera per mode

Camera state `{x, y, k}` lerped toward targets: `k` at `0.075`, `x/y` at `0.085` per frame.
Initial `k = 0.62`, target `0.78`. `x` target always 0; only `y` and `k` vary.

| Mode | zoom k | pan y | (v1 if different) |
| --- | --- | --- | --- |
| home | 0.78 | 0 | same |
| boot | 0.5 | 0 | same |
| focus | 1.42 | 172 | v1: y = 146 |
| nudge | 0.5 | 205 | same |
| group | 1.0 | 172 | same |
| log | 0.9 | 88 | same |
| add | 0.9 | 86 | same |
| time | 0.66 | 116 | same |
| reach | 0.44 | 250 | v2 only |
| invites | 0.62 | 200 | v2 only |
| propose | 0.98 | 150 | v2 only |
| pay | 0.5 | 240 | v2 only |

Manual zoom: wheel `k *= 1.09 / 0.92`, buttons `*1.28 / *0.78`, clamp `[0.35, 2.6]`; sets
`userZoom` which suppresses the per-mode `k` until a mode change or recenter. Panning is only
free in `home` (any other mode snaps `x=0, y=modeY` each frame). Recenter → `tx=ty=0`,
`userZoom=false`. Drag threshold for tap: moved < 6 and < 600 ms.

Dim behaviour (target `dimT`, lerp 0.09) — non-focused sets given here without the excluded
per-mode percentages: focus dims non-neighbours; nudge dims non-nudged; group dims non-members;
log dims unselected; add dims unlinked; propose dims unselected; reach keeps everyone lit and
raises ghosts. Ghosts (v2) get their own dim target per mode: reach > home > focus.

## 4. Node & link draw geometry

Node group (concentric, painted in this z-order): halo → ringBg → ring → core → selRing → inv → text.

- `core` r = `n.r`, stroke-width 1 (0 for me), stroke-opacity 0.45.
- `ring` (decay countdown) r = `n.r + 6`, stroke-width 1.6, round cap, `rotate(-90)`,
  `stroke-dasharray = circ*(1-dec), circ` where `circ = 2π(n.r+6)`; opacity 0.9, hidden for me.
- `ringBg` same r, stroke-width 1.6, opacity 1 (0 for me).
- `halo` (glow) r = `n.r + 11`, stroke-width 6, opacity `(1-dec)*0.3 * (0.7 + 0.3*sin(t*1.6+phase))`;
  me: base 0.4. Flash animation (merge de-dupe / accepted invite): 0.85 s, r grows `+16`,
  opacity `(1-fp)*0.85`, white.
- `selRing` r = `n.r + 12 + (1-selP)*8`, stroke-width 1.2 white, dash `3+selP*4  4`, opacity `selP*0.9`.
- `inv` (v2 invitation halo) r = `n.r + 15` (+`sin(t*3.4)*3` when incoming), stroke-width 1.1,
  dash `3 4` incoming / `1.5 5` outgoing, opacity `0.55 + 0.45*sin(t*rate+phase)`, rate 3.4 in / 2.0 out.
- Node breathing scale: `1 + (1-dec)*0.06*sin(t*2.6 + phase) + selP*0.16`; me does not breathe.
  Overall group scale `(0.25 + appear*0.75) * pulse` (ghosts: `0.2 + ap*0.8`).
- Initials text: font-size 9 (8.5 for me), weight 600, letter-spacing 0.5, centred.
- Name label: separate layer, font-size 10.5, weight 500, `text-anchor:middle`,
  at `(n.x, n.y + n.r + 15)`, opacity `show * dim * appear * bootF * 0.92`.
  Smart-label rule: show when `k > 0.86 || close >= 3 || focused || selected || mode in {log, add}`
  or the node is in the current nudge/group set.
- Ghost node: fill `#16262E`, stroke `#4E7684` width 0.9 opacity 0.75, no ring/halo/label/initials.

Links:

- Stroke width `w = (0.4 + (1-dec)*1.5)` (×1.15 in `fragment` style); glow path is the same path
  at `w*4.5`, opacity `op*(1-dec)*0.14`.
- Opacity `op = vis * (0.9 - dec*0.62) * (dec > 0.92 ? 0.55 : 1)`, `vis = min(appear)*min(dim)*bootF`.
- Fresh (`dec < 0.22`): a single straight `M…L…`.
- Decayed: fragmented dashes computed per frame — `segs = max(3, round(len/15))`,
  each segment drawn from `s0=i/segs` to `s1=(i+fill)/segs` with `fill = max(0.14, 0.98 - dec*0.72)`;
  lateral drift offset `o = amp * sin(π*mid) * sin(t*0.85 + i*1.9 + seed)` with
  `amp = ((dec-0.22)/0.78)² * 11`, seed = `l.phase*6.28`. That bell term makes the middle fray most.
- Packet (trail) dot: only when `dec < 0.42 && vis > 0.2`; travels `p = (t*(0.34 - dec*0.2) + phase) % 1`
  with ease-in-out-quad; r = `1.5 + (1-dec)*1.1`; opacity `vis * (1 - dec/0.42) * 0.95`.
- Ghost link: straight, stroke `#4E7684`, width 0.7, dash `1 3`, opacity `vis*0.8`, no glow/packet.
- Beam (v2 sent invitation): 16 pooled circles, 0.85 s each, staggered `i*0.13` s, cubic ease-out
  from me → target, r = `2 + (1-p)*3`, opacity 0.95; lifetime cull at 1.1 s.
- Group hull (group mode): polygon through members + me, each vertex pushed `+26` outward from the
  centroid, fill light, dashed `5 6`, `stroke-dashoffset = -t*14` (marching ants).
- Background grid: 46×46 pattern, opacity `0.5 + sin(t*0.4)*0.08`.

## 5. Sheet anatomy

All sheets: bottom-anchored, `padding: 0 12px 12px`; card `border-radius:20px`, inner 1 px hairline
ring, big top shadow, `padding: 15px 16px 22px` (focus & paywall sheets: `16px 18px 24px` plus a
1 px horizontal light streak across the top edge). Closed state `translateY(112%)`, open `0%`.

- **Header row**: `space-between`; left = mono label, 9 px, letter-spacing .2em, uppercase;
  right = dismiss word (`CANCEL` / `CLOSE` / `DISMISS`) 10 px, letter-spacing .14em, padding 4px 6px.
  Focus & paywall sheets use a 28×28 (26×26 for paywall) rounded `×` button instead.
- **Title**: 19 px / weight 600 (focus sheet 22 px; time sheet 26 px; paywall 23 px), line-height ~1.25.
- **Subtitle / body line**: 12.5 px, line-height 1.45–1.5.
- **Stat tiles** (focus, reach): `flex:1`, padding 10–11 px, radius 12, hairline ring; mono caption
  8–8.5 px letter-spacing .16em above a 17 px (reach: 26 px) value.
- **Signal bar**: 3 px tall, radius 2, width animates 0.7 s; caption row mono 8.5 px.
- **Chips** (context tags): padding `4px 9px`, radius 20, font 10.5 px.
- **Date chips** (log / propose): `flex:1` row, gap 6, padding `9px 4px`, radius 11, 11.5 px,
  selected = tinted background.
- **List rows**:
  - history row: `when` mono 9.5 px fixed width 52 px · `place` 12.5 px flex · `who` 10.5 px;
    padding 7 px vertical, 1 px bottom hairline; list max-height 104 px (v1: 132) scrollable.
  - nudge row: 34 px initials circle · name 14 px + line 11.5 px · days mono 15 px; padding 11×12, radius 13, gap 7.
  - group row: 26 px circle · name 13 px · note mono 10 px; padding 8×10, radius 11, gap 5.
  - reach row (v2): 26 px circle · name 13 px + stat mono 9.5 px · action pill (padding 6×10, radius 8, mono 9 px).
  - invite row (v2): 30 px circle · name 14 px + place 12 px · state mono 8.5 px; then who-line mono 9.5 px; then action row.
- **Primary button**: padding 14 (13 in group/nudge), radius 13, 13 px weight 600,
  letter-spacing .08em, cyan gradient, dark text, outer glow. **Secondary**: same box, hairline
  ring, no fill. **Tertiary/text link**: centred 11 px, letter-spacing .1em, margin-top 9.
- **Input**: padding `13px 14px`, radius 13, 16 px (propose: 12×14/radius 12/15 px), tinted fill + hairline ring.
- **Toast**: padding `9px 15px`, radius 11, 12.5 px, max-width 330 px, centred; v1 sits at
  `bottom:118px`, v2 at `top:110px`; 3400 ms lifetime, fade + 10 px slide.
- **Top chrome**: wordmark `8x` 19 px + `friends` 11 px .34em; layout segmented control
  (padding 5×9, radius 6, 9.5 px, .18em). Zoom column right at `top:112px`, three 30×30 buttons, gap 7.

## 6. Bottom nav, in order

- **v1** (5 tabs, gap 6, radius 12, label 8 px/.16em): `GRAPH` · `LOG` · `PULL` · `GROUP` · `TIME`
- **v2** (6 tabs, gap 2, radius 11, label 7.5 px/.12em): `GRAPH` · `LOG` · `PULL` · `GROUP` · `REACH` · `TIME`

`PULL` is amber and carries a pulsing 5 px dot badge (top 6, right 19). Active tab = tinted
background; inactive icon+label opacity 0.5. `GRAPH` stays active during focus mode.

## 7. Copy strings, verbatim

### Boot
- `8x`
- `assembling your graph`

### Top chrome / graph hints
- `8x` / `friends`
- `WEB`, `ORBIT`, `STRATA`
- hint line 1: `FREE FORCE LAYOUT` | `RADIUS = TIME SINCE YOU MET` | `ISLANDS = SHARED CONTEXT`
- hint line 2 v1: `{n} PEOPLE · {m} TIES`
- hint line 2 v2: `{n} PEOPLE · {f} ANON · {r} IN REACH`
- invite pill (v2): `{n} INVITATION WAITING` / `{n} INVITATIONS WAITING`; empty: `NO INVITATIONS`
- caption under the device: `drag nodes · drag to pan · tap a node to focus`
- strata group labels: `FAMILY`, `CLIMBING`, `WORK`, `UNIVERSITY`, `NEIGHBOURHOOD`

### Focus sheet
- `LAST TOGETHER`, `BIRTHDAY`, `SIGNAL STRENGTH`, `SHARED HISTORY`
- context chip: `also knows {Name}`
- history "who": `just you two` / `+{n}`
- state line (three tiers):
  - `It’s been a while since {Name}. The thread is coming apart — one message would fix it.`
  - `You and {Name} are drifting a little. You could bring {Other} along.`
  - `You and {Name} are in good rhythm right now.`
- buttons v1: `WE MET UP` · `BUILD A GROUP`
- buttons v2: `WE MET UP` · `PROPOSE` (lock glyph when not subscribed) · `BUILD A GROUP AROUND THEM`
- social row (v2): `{Name} isn’t on 8x yet — invite them by text` /
  `{Name} is on 8x · pull in their {n}-person graph` /
  `Graph merged · {n} anonymous people behind {Name}`
- relative-time vocabulary: `never`, `today`, `yesterday`, `{n} days ago`, `{n} weeks ago`, `{n} months ago`;
  spans: `longer than you can remember`, `{n} days`, `{n} weeks`, `{n} months`

### Log sheet
- header `TAP EVERYONE WHO WAS THERE` · `CANCEL`
- empty selection: `Nobody selected yet`
- chips: `Today`, `Yesterday`, `3 days`, `Last week`
- button: `PICK PEOPLE ON THE GRAPH` → `LOG 1 PERSON` / `LOG {n} PEOPLE`
- link: `+ SOMEONE NEW WAS THERE`
- toast: `{Name} is lit up again.` / `{A}, {B} and {C} are lit up again.`

### Pull (nudge) sheet
- header `THE GRAPH IS PULLING AT YOU` · `DISMISS`
- row line: `{Group} · {Name} saw them more recently` (or just `{Group}`)
- days value: `{n}d` or `∞`
- button: `SEE THEM ALL AT ONCE`

### Group sheet
- header `ASSEMBLED FROM THE GRAPH` · `CLOSE`
- title: `{A}, {B}, {C} and {D}`
- why: `Everyone already knows someone else here. The quietest of them hasn’t seen you in {span} — one table fixes five threads.`
- row note: `knows {n} of them · {last together}`
- buttons v1: `RESHUFFLE` · `PING THE FIVE`; toast `Ping drafted — “Table for six, Thursday?”`
- buttons v2: `RESHUFFLE` · `PROPOSE A DATE`

### Time sheet
- header `SCRUB THE GRAPH THROUGH TIME` · `CLOSE`
- ago label when at today: `now`
- track ends: `18 MONTHS AGO` / `TODAY`
- play button: `▶` / `❚❚`
- note: `Today. Drag back and watch links thin, fray and fall apart as the months undo themselves.`
- note (scrubbed): `{n} meet-ups within a week of this point. Links you kept alive stay bright.`

### Add-person sheet
- headers: `DROP A NEW NODE INTO THE GRAPH` → `NOW TAP WHO ALREADY KNOWS THEM` · `CANCEL`
- placeholder: `Their name`
- hint step 0: `They will appear at the centre, unattached. Then you wire them into the people they already know.`
- hint step 1: `{n} connections so far. Every tap springs a new tie into place.` (singular `connection`)
- button: `DROP THE NODE` → `DONE`
- toast: `{Name} is in the graph with {n} ties.`
- new node's `via`: `you just added them`; seeded event places `you added them`, `you logged this`

### Reach sheet (v2)
- header `HOW FAR YOUR GRAPH REACHES` · `CLOSE`
- stat captions: `YOUR PEOPLE`, `ANONYMOUS FoF`, `IN REACH`
- `{k} of {n} friends on 8x have shared their graph. {m} more people are one tap away.`
- `{Name} reaches {n}. You reach {m}.`
- row stat: `{n} people · reaches {m}`; action `PULL IN` → `MERGED`
- toast: `{Name}’s graph merged — {n} more people in reach, all anonymous.`
- toast (from focus sheet): `{Name}’s graph merged — anonymous, but it counts.`

### Invitations sheet (v2)
- header `SIGNALS FROM YOUR GRAPH` · `CLOSE`
- states: `AWAITING YOU`, `WAITING FOR THEM`, `ACCEPTED`, `DECLINED`
- who-line fallback: `just you two`; outgoing row name: `You proposed`
- actions: `I’M IN` · `CAN’T`
- footer: `Answering is always free. Starting something is the part that needs 8x Live.`
- toast: `You’re in. {place}.`
- fixture invites: `Bloc Fabrik, Thursday 19:00`, `the long table, Sunday lunch`

### Propose sheet (v2)
- header `PROPOSE A MEET-UP` · `CANCEL`
- empty target: `nobody yet`
- chips: `Tomorrow`, `Thursday`, `Sunday`, `Next week`
- placeholder: `Where?` (default value `Bar Estrela`)
- button: `SEND IT DOWN THE LINKS`
- footer: `THEY ANSWER INSIDE THEIR OWN GRAPH`
- toast: `Invitation on its way to {A}, {B} and {C}.`
- reply toast (after 3800 ms): `{Name} said yes. It’s on.`

### Paywall sheet (v2)
- eyebrow `8X LIVE`
- title: `Your graph is yours for free. Reaching into it is the paid part.`
- left column `OFFLINE · FREE`: `Your whole graph` / `Logging meet-ups` / `Reach & comparisons` /
  `Merging friends’ graphs` / `Answering invitations`
- right column `LIVE · €4 / MONTH`: `Everything free, plus` / `Propose a meet-up` /
  `Assemble & ping a group` / `Nudge a fading link` / `See who answered`
- button: `GO LIVE — €4 / MONTH`
- footer: `Your graph never leaves your phone. Only the invitation does.`
- toast: `You’re live. Your graph can reach back now.`

### Fixture vocabulary (demo data)
Groups: `Family`, `Climbing`, `Work`, `University`, `Neighbourhood`.
Places: `Casa Rosa`, `Bloc Fabrik`, `the Praça`, `Rui’s kitchen`, `tram 28`, `the rooftop`,
`Cine Nova`, `Sunday market`, `Serra trail`, `Bar Estrela`, `the allotment`, `Studio 4`,
`Ana’s balcony`, `the long table`.
Via lines: `sister`, `dad`, `mum`, `cousin`, `Rui’s partner`, `met at Bloc Fabrik`, `via Tomás`,
`via Sofia`, `via Kaito`, `desk neighbour`, `same team`, `via Hannah`, `via Omar`,
`first year flatmate`, `via Ana`, `studio partner`, `via Daniel`, `via Mira`, `downstairs`,
`via Greta`, `the café`.
