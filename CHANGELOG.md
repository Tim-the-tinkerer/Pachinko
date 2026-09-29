# Changelog

All notable changes to **Pachinko** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [1.0.13] - 2026-09-28

### Fixed

- Two sevens and a miss, including a blank third reel, is a reach and does not pay.
- Pause freezes the reels, Fever, and a BAR attacker window. Holding Space to fire no longer resumes on the key repeat.
- Switching cabinets during the demo clears the balls already on the field and keeps the Arcade layout. Leaving a game shows the cabinet chosen from the View menu.
- Command-M minimizes, and Command-Shift-M toggles sound effects. The Help alert keeps the keyboard.
- Closing Settings disarms Reset Wear. The start plaque on the main screen starts a game.
- A full-screen choice made while the window is still animating stays on the mode you picked.
- The music player is kept until it has finished, including when music is turned off mid-track.

---

## [1.0.12] - 2026-09-27

### Added

- Full screen. Settings chooses window or full screen, and that choice is remembered. Command-F and the green window button use the same mode.

---

## [1.0.11] - 2026-09-27

### Changed

- Help and the readme describe cabinet and wheel wear.
- Settings can turn wear off, which hides the scratches and puts the wheel back to its normal speed, or reset the wear on every cabinet.

---

## [1.0.10] - 2026-09-27

### Changed

- The main screen has a Settings panel. Difficulty, CRT glass, music, and sound effects live there. The cabinet list stays on the parlor screen.

---

## [1.0.9] - 2026-09-27

### Fixed

- A reach (two sevens and a miss) no longer pays out as a pair. The leftover reel draw can no longer mint an extra Fever, bars, cherries, or stars.
- During Fever the wheel's push matches how fast the arms are actually turning.
- A BAR bonus timer can no longer close a later attacker opening.
- Pausing no longer lets an in-flight step spend a ball or move the board.
- The demo uses Arcade firing and reel odds with its Arcade board.
- A new game no longer inherits the previous handle cooldown.
- Saved high scores are sorted and kept to ten.

---

## [1.0.8] - 2026-09-27

### Fixed

- Short sound effects no longer crash the app a few minutes into play. Each player stays alive until the system has finished telling it the clip ended.

---

## [1.0.7] - 2026-09-27

### Changed

- The cabinet frame has side lamps, a slow glass sheen, a payout flap, and light wear that deepens on a machine you keep playing.
- Balls cast a small contact shadow that stretches a little with speed.
- The demo aims at the start hole, holds, sweeps the board, then tries a side pocket, instead of sawing the handle back and forth.
- After a long run of balls, each cabinet's wheel settles a little: Dragon and Koi slow down, Neon, Lantern, and River speed up. Sakura stays as it was.

---

## [1.0.6] - 2026-09-27

### Changed

- Ball physics runs off the main actor, so drawing the cabinet is not stuck behind the collision work.
- Each ball only tests nearby nails, and ball-to-ball checks no longer copy the whole ball list six times a frame.

---

## [1.0.5] - 2026-09-27

### Changed

- The launcher is a spring and plunger that cocks with the handle and snaps when a ball fires. The wheel has a turning hub.
- Nail hits vary in pitch and loudness with impact speed. Gold nails and the wheel ring brighter.
- Pockets flare with a ring and spokes when a ball lands.
- Fever strobes the board, chases the marquee lamps, chimes each time the attacker opens, and throws sparks.

---

## [1.0.4] - 2026-09-27

### Changed

- Sakura stays the classic field. Gold Dragon uses wider, shorter nail rows, a wheel on the right, and tulips at different heights. Shinjuku Night uses a leaning grid and a wheel on the left.
- Each cabinet has its own playfield wash, ornament, and procedural tune.

---

## [1.0.3] - 2026-09-27

### Added

- Three more boards. Koi Garden is a wide, slow field. Lantern Alley runs diagonal and keeps the start hole to the right. Split River uses a fast center wheel to kick balls into two currents.
- Each new board has its own lacquer and tune. Sakura, Dragon, and Neon stay on the classic field.

---

## [1.0.2] - 2026-09-27

### Fixed

- The board no longer crashes after a minute of play. Reel symbols and payout labels are drawn as normal text, and the canvas is updated once per frame.

---

## [1.0.1] - 2026-09-27

### Fixed

- Nail gaps are wider than a ball. The top spreader row sits a full step above the field, duplicate funnel nails are gone, and the outer nails clear the side walls.
- Start-hole lips stay passable on Novice, Arcade, and Insane. Insane is still the narrow shot.
- The closed attacker lid is a peak, so balls slide off instead of parking on a flat bar.
- Pocket and reel payouts no longer outrun the balls you spend. Ordinary play drains the tray. Fever is what fills it back up.

---

## [1.0.0] - 2026-08-26

### Added

- Native macOS pachinko parlor
- Three cabinets: Sakura Hanabi, Gold Dragon, Shinjuku Night
- Nail field, windmill, start hole, tulips, attacker gate, out hole
- Handle-powered launches with a skill drop line
- Digital 3-reel LCD, reach, and Fever rounds
- Novice / Arcade / Insane difficulty
- Attract-mode demo and high scores with initials
- Per-cabinet palettes and music, CRT overlay, procedural SFX
