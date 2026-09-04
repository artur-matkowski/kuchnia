<!--
LinkedIn post, sized to the 3000-character limit.

Everything between the POST markers is what gets pasted. Nothing else.
Re-check the count after ANY edit:

  sed -n '/^POST BEGIN$/,/^POST END$/p' article/kuchnia-llm-architecture.md | sed '1d;$d' | wc -c
-->

POST BEGIN
I now write code for two different readers.

I wanted to build a Qt/QML app the way it's done in 2026. I was on a clock: an interview scheduled, and I wanted to bring it.

I run a home server and a DIY smart home, so I built a panel for it. Five cameras, the gate, the hot water tank, the weather, a map of where everyone is. Six screens, two keys.

A spike with Claude proved the plumbing — RTSP, MQTT, Postgres, a weather API. Easy.

Then the actual problem. Animations.

Claude can take screenshots. For states they're perfect: is the card in the right place, is anything overlapping. For animation they're worthless. A screenshot of a transition is one frame. It says nothing about whether the thing moved well, or at all.

So the model was blind on exactly the part I cared most about.

I could have written them myself. Instead I asked how to design a system that plays to what it is.

A text prediction machine with advanced attention mechanisms.

 Boilerplate is exactly that. A lot of similar text, one simple pattern. Abstraction isn't beyond it. But models were good at bulk text long before they were good at deep abstraction, and context window keeps growing. Therefore boilerplate has always been the more predictable quality path for LLMs. So I build on the tool's strengths, not on cutting edge claims it 'can do'.

So: one screen on at a time. Every element that moves declares its own position for every screen, and its own animation for every ordered pair. No duration constant, no stagger helper. Where three cards leave one after another, the pauses are written 60, 120 and 200 — by hand, in three places.

213 position declarations. 60 transitions. 23 durations. 25 animated elements. The base class they inherit is 70 lines with no animation at all.

The most boring structure I could have chosen. Nothing to working in three hours.

It worked because it's local, checkable and additive — one block to read, one pattern to verify. 
Abstraction is compression for human working memory. The model doesn't have that problem, so it does not need it. It has a different problem — it can't see the result. So you spend the constraint you no longer have to buy down the one you do.

What it couldn't do: every timing number came from me in front of the screen going "no — slower." The model placed them; it never chose one. Structure to the model, taste to the person.

Ten hours for the core. Not because the model types fast — because I stopped asking it to be good at the thing it's bad at.
POST END

---

# Notes

**The clip.** One video attached to the post; LinkedIn puts it above the text, so it does the
establishing-shot job on its own. From the camera screen press Right five times, all the way
round the ring and back — about 15 s. Pace it: let each screen land and hold a beat before the
next press. Transitions run ~550 ms, so at a walking pace the per-element stagger reads without
slowing anything down. Leaving the cameras, one tile zooms at the viewer, one flies off the
top, one drops off the bottom, each a beat after the last. Shoot on the board, not the desktop
build. Nothing here has been observed by me — this is what the code says should happen.

**Dropped for length**, in the order I would restore them if this became an Article: the
repeater paragraph (the first abstraction deleted — the most vivid image in the long draft);
the three-bullet expansion of local / checkable / additive; the carousel line about eighteen
byte-identical transitions becoming one shared file, which is what pre-empts "so you just hate
DRY?" in the comments.

**Outside backing, if wanted.** A Berkeley benchmark this year scores generated UI code on
appearance and on motion separately: leading models land around 0.84 on appearance and 0.29 on
motion. Fine-tuning made it worse; iterating improved the appearance and left the motion where
it was. Animation2Code, arXiv:2606.28593. I have not read the paper — the figures came from a
research pass, so check them before putting your name to them. It does not fit in the budget
as things stand, and the argument does not need it.
