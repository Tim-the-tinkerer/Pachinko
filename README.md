# Pachinko

**Version 1.0.9** — a native macOS pachinko parlor written in Swift.

Crank the handle, rain steel balls through a field of nails, and chase **7-7-7** for **FEVER**. Six cabinets. Sakura keeps the classic nail field. Every other cabinet moves the wheel, the nails, or both, and each one has its own backdrop and tune.

## Cabinets

| Cabinet | Board | Machine |
|---------|-------|---------|
| **Sakura Hanabi** | Classic staggered field, blossom wash | CR HANABI |
| **Gold Dragon** | Wider scale nails, wheel on the right, staggered tulips | CR RYU |
| **Shinjuku Night** | Leaning city grid, wheel on the left | CR NEON |
| **Koi Garden** | Wide nails, slow wheel, low start hole | CR KOI |
| **Lantern Alley** | Diagonal lanes, start hole to the right | CR CHOCHIN |
| **Split River** | Fast center wheel kicks balls into two currents | CR NAGARE |

Hit the **START** hole to spin the digital reels. Sevens start Fever: the **attacker** gate cycles open and pays a pile of balls. Side **tulips** pay a couple back. Miss, and the ball is gone. Ordinary play spends the tray down. Fever is what fills it again.

## Features

- Nail / wall / windmill physics with substeps and ball-on-ball collisions
- Handle skill shot — power sets where the ball drops on the board
- Digital 3-reel LCD with reach production
- Fever rounds with an opening attacker gate
- Novice / Arcade / Insane difficulty
- Attract-mode demo, high scores with initials
- Per-cabinet palettes and music, CRT glass, procedural SFX
- Pure SwiftUI + AppKit, no external packages

## Controls

| Key | Action |
|-----|--------|
| Hold `Space` or click the board | Fire balls |
| `←` `→` / `A` `D` / drag up-down | Handle power |
| `P` | Pause |
| `Esc` | Menu |
| `T` | Cycle cabinet |
| `C` | Toggle CRT |
| `M` | Toggle music |
| `1` `2` `3` | Difficulty (menu) |

On the classic boards, the middle of the handle drops over the start hole. Lantern Alley keeps that hole to the right.

## Difficulty

| Mode | Tray | Chucker | Fever | Fire rate |
|------|------|---------|-------|-----------|
| **Novice** | 125 | wider | 9% · 16 rounds | faster |
| **Arcade** | 100 | normal | 5.5% · 12 rounds | normal |
| **Insane** | 75 | tight | 3.5% · 8 rounds | slower |

Every nail gap, including the start-hole lips and the space beside the side walls, is wider than a ball. Insane is the narrow shot; Novice is the wide one. The closed attacker lid is a peak, so a ball slides off instead of sitting on it.

## Build & run

```bash
cd Pachinko
chmod +x build-app.sh
./build-app.sh
```

Requires macOS 13+ and Xcode.

## Project layout

```
Pachinko/
├── Package.swift · AppInfo.plist · build-app.sh
├── CHANGELOG.md · README.md
└── Sources/Pachinko/
    ├── Engine/     # Physics, nail field, game loop
    ├── Models/     # Pockets, reels, high scores
    ├── Views/      # Menu, HUD, canvas, CRT
    └── Sound/      # Procedural music + SFX
```
