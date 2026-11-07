# Extreme Angler - One Key Fishing

**One key to cast, the same key to catch.** Extreme Angler turns fishing in **WoW Forever** into a single keybind and adds a clean stats card, a bite timer and helpful notifications - all in a lightweight addon with no libraries.

> **No automation.** Extreme Angler never casts, catches or loots on its own. Every action happens because *you* pressed the key. It only changes what your key does at the right moment.

---

## How it works

1. Press your fishing key → **cast**.
2. Wait for the splash (Extreme Angler turns the splash up for you).
3. Press the **same key** → **catch**. Your key instantly goes back to casting.

That's it. The default key is **`<`** - change it any time in the settings or with `/ea key F`.

---

## ⚡ Smart Cast - your key always does the right thing

This is what makes Extreme Angler feel different. Every time you press the key, it checks your situation and does the **one thing you need next**:

| Your situation | What the key does |
|---|---|
| No fishing pole equipped | Equips the pole from your bags (your weapons come back when you stop fishing) |
| Pole has no lure | Applies the **best usable lure** in your bags |
| Ready to fish | **Casts** |
| Bobber is out | **Catches** the fish |
| Just caught something | Instantly ready to **cast again** - no waiting, no rebinding |

No macros to write, no extra buttons for poles or lures, no switching keys between casting and catching. Walk up to the water with your sword in hand, keep pressing one key, and fish. Each press is still exactly one action that **you** choose to make.

---

## Features

### One key fishing
- One keybind casts Fishing and catches the fish (uses the game's *Interact With Target* on the bobber).
- **Fishing pole swap:** no pole equipped? The first press equips one from your bags. When you stop fishing, your weapons are re-equipped.
- **Lures:** if your pole has no lure, the key applies the best usable lure from your bags first. A warning shows when you're out.
- **Auto loot** while fishing, then your own setting is restored.

### Hear every splash
While you fish, a sound profile makes the splash easy to hear - effects to max, music and ambience muted (each option can be toggled). Everything is restored when you stop, even after a crash or disconnect.

### Stats card
- Fishing **skill bar** with your lure bonus and how many points to the cap (flashes on skill up).
- **Session** casts and catches.
- **Zone loot table:** the most common catches in your current zone, with item icons, quality colors and percentages. Hover a row for the item tooltip.
- Collapses to a single line. Lock, collapse and settings buttons right on the card.

### Bite timer
A slim bar that fills while your bobber is out. The **bite zone** - the window where fish usually bite - is highlighted, and it **learns from your own catches**.

### Notifications
Small cards that slide in and fade out:
- **New catch!** - first time you catch an item (or first time in this zone)
- **Rare catch!** - uncommon quality or better
- **Fishing skill up** - with a reminder to train when you hit the cap
- **Session summary** - casts, catches, catch rate and new finds

Each card type has a fitting game sound (or pick one sound for all, or none).

### Lightweight
- ~140 KB of memory, no libraries.
- Settings panel is only built when you open it.
- Turn the addon off with `/ea` and it goes to sleep (stops listening to game events).

### Works with your other addons
Catches are counted from loot messages, so stats stay accurate with fast auto-loot addons like **Leatrix Plus**.

---

## Commands

| Command | What it does |
|---|---|
| `/ea` | Turn Extreme Angler on/off |
| `/ea options` | Open the settings |
| `/ea key <KEY>` | Change the fishing key (e.g. `<`, `F`, `BUTTON3`, `SHIFT-F`) |
| `/ea lock` | Lock/unlock the card, timer and notifications for moving |
| `/ea panel` | Show/hide the stats card |
| `/ea sound` | Toggle the fishing sound profile |
| `/ea weapon` | Re-equip your previous weapons now |
| `/ea test` | Show a test notification |
| `/ea reset` | Reset statistics |
| `/ea mem` | Show memory usage |
| `/ea welcome` | Show the welcome message again |

Settings are also under **Options → AddOns → Extreme Angler**.

---

## FAQ

**Is this allowed?**
Yes. Extreme Angler only uses the normal addon API. It never presses keys for you and never acts without your input - one key press, one action.

**My key does something else now.**
While Extreme Angler is on, it takes over your chosen key. Turn it off with `/ea` and the key goes back to normal, or pick another key in the settings.

**Can it cast again automatically after a catch?**
No - that would be automation. After a catch your key is instantly ready to cast again, so it's just one more press.

**The panel is in the way.**
Click the lock icon on the card (or `/ea lock`), drag it anywhere, then lock it again.

---

## Feedback

WoW Forever is still evolving, so things can change. Found a bug or have an idea? Leave a comment - include any error message and what you were doing.
