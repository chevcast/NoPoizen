# NoPoizen

NoPoizen is a focused quality-of-life addon for **Rogues** that helps you avoid fighting without proper poisons active.

It watches your current poison state and only warns when you are missing required poisons.

## What It Does

- Monitors **lethal** and **non-lethal** poison categories.
- Shows a center-screen reminder widget when your poison setup is incomplete.
- Supports talent-based poison limits:
  - Default: `1 lethal + 1 non-lethal`
  - With `Dragon-Tempered Blades`: `2 lethal + 2 non-lethal`
- Uses a two-row display:
  - Row 1: Lethal Poisons
  - Row 2: Non-Lethal Poisons
- Removes already-applied poisons from each row.
- Hides an entire row once that category is fully satisfied.

## HUD Edit Mode Support

NoPoizen integrates with Blizzard HUD Edit Mode so the reminder behaves like a proper movable UI element.

- Drag the indicator to place it where you want.
- Click it in Edit Mode to open the indicator settings dialog.
- Scale the indicator up/down in real time.
- Revert or reset changes using Edit Mode-compatible controls.

## Options (Blizzard AddOns Panel)

Path: `Options -> AddOns -> NoPoizen`

Current options:

- Show visual indicator when poisons are missing
- Play audio indicator when poisons are missing
- Audio indicator volume

Notes:

- The volume slider is disabled when audio is turned off.
- Default volume is `50%`.

## Audio Alert

- Uses a local sound file: `nopoizen.mp3`
- Plays when you enter a missing-poison state.
- Volume is controlled by the NoPoizen slider.

## Slash Commands

- `/nopoizen options` or `/np options` - Open NoPoizen settings
- `/nopoizen edit` or `/np edit` - Open HUD Edit Mode
- `/nopoizen test` or `/np test` - Run addon tests

## Scope and Philosophy

NoPoizen is intentionally small and specific.

- No profile system
- No cluttered configuration tree
- No extra modules unrelated to poison readiness

Everything is built around one goal: **keep your poisons correct with minimal friction**.

## Saved Settings

All settings are **per-character**, including:

- visual/audio toggles
- audio volume
- widget position
- widget scale

## Compatibility Notes

- Retail WoW addon
- Rogue-only behavior by design
- Indicator logic automatically reacts to spec/talent changes and aura updates

## Feedback

If you find a poison/talent edge case, report it with:

- your spec
- your selected poison talents
- which poisons were active
- expected vs actual indicator behavior

That makes fixes very fast and precise.
