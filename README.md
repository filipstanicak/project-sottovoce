<p align="center">
  <img src=".github/readme/sottovoce-hero.png" alt="A crowded street in Vessalia's glassmakers' quarter at dusk, where repeated civilian silhouettes hide the human players." width="100%">
</p>

<h1 align="center">Project Sottovoce</h1>

<p align="center">
  <strong>A multiplayer game of patience, observation, and the terror of being watched.</strong>
</p>

<p align="center">
  <a href="https://github.com/filipstanicak/project-sottovoce/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/filipstanicak/project-sottovoce/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Godot 4.7.1" src="https://img.shields.io/badge/Godot-4.7.1-478CBF?logo=godot-engine&logoColor=white">
  <img alt="Status: pre-alpha" src="https://img.shields.io/badge/status-pre--alpha-B77945">
</p>

Project Sottovoce is an online social-stealth game for 4–6 players, set in the dense glassmakers' quarter of the fictional Renaissance city of Vessalia.

Every player hunts one contract while being hunted by someone unknown. The streets hold 60–90 civilians, including 8–12 identical clones of every playable persona. Finding your contract means reading movement, hesitation, routes, and mistakes without making your own behaviour stand out.

Matches reward restraint. A patient approach can be worth several times more than a fast kill, while speed raises suspicion and spends the anonymity that keeps you alive.

## The game

| Principle | What it means in play |
|---|---|
| **The crowd is a mechanic** | Civilians provide cover, react to violence, form moving groups, and reveal disturbances. |
| **Speed spends anonymity** | Walking keeps you ordinary. Running finds your contract faster and makes you easier to read. |
| **Everyone hunts and is hunted** | Your attention is always divided between identifying one person and watching for another. |
| **The prey has teeth** | A correct read can become a stun, an escape, or a defensive ability rather than a helpless death. |
| **Patience wins the match** | Score rewards quiet approaches, blending, timing, and variety more than raw kill count. |

There is no minimap and no nameplate over another player. The Compass narrows the search without resolving it for you. The final answer still has to come from the crowd.

## Current state

The project is in **pre-alpha** and the core loop is playable in greybox form. The current visuals are functional development art; the final environment, characters, animation, and audio are still ahead.

Already working:

- server-authoritative multiplayer with direct-IP sessions
- client prediction, reconciliation, interpolation, and lag-compensated combat
- the Vetraio district plus a compact systems sandbox
- movement, traversal, blending, suspicion, detection, contracts, kills, stuns, escapes, respawns, and scoring
- a pooled and networked civilian crowd with clone-parity rules
- match phases, final-contract scoring, and a results screen
- an automated architecture, unit, integration, lint, export, and asset-safety pipeline

The live plan and its exit criteria are in the [roadmap](docs/40_backlog/ROADMAP.md).

## Run a local session

### Requirements

- [Godot 4.7.1 stable](https://godotengine.org/download/archive/4.7.1-stable/)
- Windows for the one-click launcher scripts
- Git

Clone the repository, then set the `GODOT` path near the top of `play.bat` and `sandbox.bat` to your Godot executable.

```powershell
git clone https://github.com/filipstanicak/project-sottovoce.git
cd project-sottovoce
.\play.bat
```

`play.bat` performs a clean import, starts a dedicated server, adds three bots, opens one local client, and shuts the session down when the game window closes.

For a faster mechanics bench with a smaller map and crowd:

```powershell
.\sandbox.bat
```

Both launchers accept optional bot, port, crowd, and seed arguments; their headers document the exact forms.

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look |
| `Ctrl` | Blend-walk |
| `Shift` / double-tap `Shift` | Run / sprint |
| `Space` | Traverse |
| `E` | Use a blend point |
| Left mouse | Kill |
| Right mouse | Stun |
| Middle mouse | Crowd scan |
| `Q` / `F` | Ability slots |
| `Tab` | Score |
| `Esc` | Release the mouse / menu |
| `F3` | Toggle development overlays |

Gamepad bindings ship alongside keyboard and mouse bindings.

## Technical shape

- **Engine:** Godot 4.7.1, Forward+
- **Language:** typed GDScript
- **Simulation:** 60 Hz pawn integration, 30 Hz authoritative network tick
- **Networking:** ENet with separate state, event, and session channels
- **Authority:** the server owns movement outcomes, suspicion, contracts, combat, and score
- **Architecture:** pure rules in `scripts/core/`, server systems in `scripts/systems/`, transport in `scripts/net/`, client rendering in `scripts/presentation/`
- **Testing:** GUT architecture guards, unit suites, multi-system integration tests, lint, imports, exports, and repository policy checks on every pull request

The architecture is intentionally strict because many failures in a networked stealth game look correct on one client while being wrong everywhere else.

## Documentation

The documentation is a maintained design and engineering corpus, not a loose notes folder.

- [Documentation index](docs/README.md)
- [Vision and six design laws](docs/10_gdd/01_vision.md)
- [Social-stealth design](docs/10_gdd/03_social_stealth.md)
- [Technical architecture](docs/20_tdd/01_architecture.md)
- [Network protocol](docs/30_bible/NETWORK_PROTOCOL.md)
- [Art direction](docs/30_bible/ART_BIBLE.md)
- [UI and UX specification](docs/30_bible/UI_UX_SPEC.md)
- [MVP scope fence](docs/00_meta/SCOPE_FENCE.md)

Before changing the project, read [AGENTS.md](AGENTS.md), then the complete operating manual in [CLAUDE.md](CLAUDE.md). Each story links the design and technical documents that govern it.

---

<p align="center">
  <em>Move like the crowd. Read the person inside it.</em>
</p>

<sub>README artwork is non-shipping concept art created for this repository. Its generation record is kept in [.github/readme/ARTWORK.md](.github/readme/ARTWORK.md).</sub>

