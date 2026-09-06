---
id: DOC-LOCAL-AUDIT-2026-09-06
title: Local project audit and HUD readability pass
version: 0.1.0
status: review
owner: Project Owner
last_updated: 2026-09-06
depends_on: [DOC-SCOPE-FENCE, ADR-0013, ADR-0016, BIBLE-UI-UX, US-0073]
---

# Lokaler Projektcheck — 6. September 2026

Die Regeln sind deutlich weiter als ihre wahrnehmbare Darstellung. Für die gewünschte
Nähe zur Referenz bringt die nächste lesbare Begegnung mehr als zusätzliche Fähigkeiten
oder eine aufwendigere Menügestaltung: eine Persona zwischen identischen Zivilisten
erkennen, eine Absicht lesen, handeln und die Konsequenz verstehen.

Dieser lokale Stand verbessert das vorhandene HUD und behebt eine falsche Gefahrenanzeige.
Er ersetzt weder den bestehenden Meilensteinplan noch dessen menschlichen Spieltest.
Es wurden keine Gameplay-Tunables, Protokollfelder oder bereits vergebenen IDs geändert.
Bis zum Abschluss der lokalen Prüfung wurden keine Assets importiert, keine Commits
erstellt und keine Änderungen gepusht. Anschließend hat der Owner die Veröffentlichung
der geprüften Änderungen auf einem eigenen Branch mit Pull Request freigegeben;
direkte Pushes auf `main` und ein Merge bleiben ausgeschlossen.

## 1. Grundlage und Reichweite

Ausgangspunkt ist der lokale Checkout bei `38c6d0e`. Vor dieser Arbeit waren nur
`AGENTS.md`, `.agents/` und `.codex/` unversioniert vorhanden; sie gehören zum vorhandenen
Arbeitsumfeld. Ein Abgleich mit einem aktuelleren Remote-Stand wurde nicht durchgeführt.

Der Dokumentbestand vor diesem Bericht umfasst 169 Markdown-Dateien: 26 Meta-Dokumente,
8 GDD-Kapitel, 12 TDD-Kapitel, 18 Bible-Dateien, 102 Backlog-Dateien, 2 Tuning-Dateien und
den Index. Unter den 99 Story-Dateien stehen 57 auf `done`, 21 auf `in-progress` und 21 auf
`draft`. Diese Kopfzeilen sind keine Aussage darüber, ob eine Funktion im Client sichtbar ist.

Der Gesamtkorpus wurde strukturell inventarisiert. Die Detailprüfung konzentriert sich auf
die geltenden Guardrails, ADRs, den Meilensteinplan sowie Mechaniken, Assets und Darstellung.
Es liegt keine vollständige Satz-für-Satz-Konsistenzprüfung aller historischen Texte vor.
Der lokale Dokumentindex liegt unter `reports/hud-audit/document-inventory.md`.

Die Referenzrecherche ist außerhalb des Repository abgelegt, entsprechend ADR-0013.
Unbelegte Zahlen aus Erinnerungen oder Sekundärquellen wurden nicht in Tunables übersetzt.

## 2. Was tatsächlich vorhanden ist

| Bereich | Befund im Code | Bedeutung für das Spielerlebnis |
|---|---|---|
| Verträge | `ContractCycle` hält einen geschlossenen Zyklus; `ContractSystem` repariert ihn nach Tod, Flucht und Stun. | Ein eigener Vertrag und genau ein eigener Verfolger sind eine bewusste Grenze, kein fehlendes Mehrfachziel-Feature. |
| Social Stealth | Verdacht, Stufen, Blend-Aktionen und Quellen werden serverseitig berechnet. | Das Fundament für geduldiges Spiel existiert; die Ursachen müssen im HUD verständlich bleiben. |
| Kampf | Kill, Stun, Reichweite, Sichtprüfung, Zustandsbedingungen und Lag-Kompensation sind getrennt prüfbar. | Keine neue clientseitige Erfolgsschätzung ergänzen. Die fehlende sichtbare Reaktion ist nicht durch veränderte Reichweiten zu lösen. |
| Verteidigung | Flucht ist implementiert; ADR-0018 stärkt die Verteidigung, ADR-0019 lässt einen gestunnten Verfolger den Vertrag verlieren. | Diese bereits beschlossenen Regeln erhalten. Stun und Flucht sind eigenständige Erfolgserlebnisse. |
| Wertung | Ereignislog, Fold und Bonusbewertung sind implementiert. | Die Anzeige muss die ausgezahlten Gründe erklären; ein Endergebnis benötigt zusätzlich das Match-Ende. |
| Fähigkeiten | Pipeline, Cinderfall und Lunge existieren; auch der defensive Lunge-Pfad ist vorhanden. | Frühere Aussagen, die Pipeline oder Lunge seien grundsätzlich noch ungebaut, sind veraltet. Vollständige Loadout-Präsentation fehlt trotzdem. |
| Bewegung | Deterministische Pawn-Zustände, lokale Vorhersage und Traversal bestehen. | Spielgefühl benötigt zusätzlich passende sichtbare Zustandswechsel und gleiches Bewegungsverhalten der Klone. |
| Menge und Karte | Crowd-Simulation, Replikation, District-Blockout und kleine Debug-Testkarte existieren. | Die Testkarte eignet sich für reproduzierbare Begegnungen; sie belegt keine Dichte-, Circuit- oder Respawn-Qualität des Districts. |
| Match-Ablauf | `server_root.gd` aktiviert den Testbetrieb direkt; `GameState` bleibt ein Stub. | Start, Zeitablauf, Ergebnisse und erneuter Einstieg sind noch kein vollständiger Spielablauf. |

Die Quellbereiche sind `scripts/core/`, `scripts/systems/`, `scripts/net/`, `scripts/pawn/`
und `scripts/server/`. Die laufende Darstellung wurde anhand der echten Client-Szene
und ihres HUD-Probes geprüft, nicht anhand eines separat gezeichneten Mockups.

## 3. Assets und sichtbare Mechaniken

| Befund | Konkrete Stelle | Nächster sinnvoller Schritt innerhalb des Plans |
|---|---|---|
| Unter `assets/` liegen Platzhalterdateien statt fertiger Figuren, Clips und Klänge. | `assets/`, `ASSET_LICENSES.md` | Assetbedarf an lesbaren Begegnungen ausrichten; jede externe Datei mit Lizenzzeile aufnehmen. |
| Vier prozedurale Persona-Entwürfe existieren, werden im laufenden Spiel aber nicht als gemeinsame Figurenbasis verwendet. | `scripts/presentation/pawn_visuals/persona_body.gd`, `scenes/pawn/`, `scripts/presentation/npc_view.gd` | Erst eine wahrheitsgemäße gemeinsame Appearance-Quelle für Spieler und deren Klone schaffen, dann dieselbe Body-Darstellung anschließen. |
| Remote-Pawns verwenden Position und Ausrichtung; vorhandene Render-Zustände führen noch nicht zu vollständigen Aktionsanimationen. | `scripts/net/client/remote_pawns.gd`, US-0055, US-0046 | Zuerst Gehen, Stillstehen, Blend, Wind-up, Stun, Stagger und Respawn lesbar machen. Spieler und Klone müssen dieselben sichtbaren Hinweise geben. |
| Das Vertragsbild erhält beim Lock-Abschluss keine echte Persona. | `scripts/presentation/hud/hud_bridge.gd`, `portrait_widget.gd` | Die serverseitig erlaubte Information bis zum Widget führen; kein zufälliges oder aus Slotnummern geratenes Gesicht zeichnen. |
| `Audio.play()` ist leer. | `scripts/presentation/audio/audio.gd`, US-0075 | Informationsaudio zuerst: Warnung, lesbare Fähigkeitstells und passende Schritte mit den vorgesehenen Untertiteln. Musik und Variationsreichtum folgen später. |

Die wichtigste Gestaltungsprobe ist deshalb keine schöne Einzelfigur. Es ist dieselbe
Persona gleichzeitig als Spieler und als mehrere Zivilisten in derselben Szene. Ein
unterschiedlicher Gang, Schatten, Materialwechsel oder Footstep-Rhythmus würde das
Deduktionsspiel umgehen. Genau diese Parität muss vor größerem Art-Aufwand sichtbar sein.

## 4. Lokal umgesetzte UI-Verbesserungen

Der Owner hat den Widerspruch zwischen US-0073 und UI_UX_SPEC ausdrücklich zugunsten
der UI-Spezifikation entschieden: Vertragsbild oben links, Status unten links.

- Das HUD folgt dieser Anordnung und hält die Instrumente auf breiten Displays innerhalb
  eines zentrierten 16:9-Bereichs. Die Vignette bleibt an den tatsächlichen Bildschirmrändern
  und liegt hinter den Instrumenten.
- Status, Verdachtsursachen und Wertungsgründe sind größer und kontrastreicher. Die fünf
  gleichzeitig aktiven Ursachen werden umgebrochen statt über die Fläche hinauszulaufen.
- Negative Wertungen erhalten einen eigenen dunklen, warmen Hintergrund. Vorzeichen und
  Beschreibung bleiben erhalten; die Unterscheidung hängt nicht allein von der Farbe ab.
- Das Vertragsfeld unterscheidet unbekannt und abgeschlossenen Lock sichtbar. Der
  Identifiziert-Platzhalter ist ausdrücklich noch kein funktionierendes Persona-Porträt.
- Die Debug-Anzeigen starten verborgen. F3 schaltet sie samt District-Tönung wieder ein;
  die Debug-Karte sitzt unterhalb des Vertragsfelds.
- Ein tatsächlicher Fehler ist behoben: Nach dem Ende einer Verfolgung blieben die zuletzt
  gezeichneten Ringe sichtbar. Der Wechsel auf null löst jetzt ein Neuzeichnen aus, auch
  wenn die anschließende Ruhephase keine weiteren Zeichenaufrufe benötigt.

Der Probe wartet für Momentaufnahmen jetzt nach vergangener Anzeigezeit. Die frühere
Wartezeit in Frames verfehlte kurze Pulse und gestaffelte Score-Einblendungen je nach FPS.

Dies ist eine lesbare Zwischenstufe gemäß SCOPE_FENCE §1.2 und §5. US-0073 bleibt offen:
echtes Porträt, Ability-Slots sowie die ausstehenden Zugänglichkeits- und Spieltests sind
damit nicht erledigt. Es wurde kein fiktiver Match-Timer oder erfundener Cooldown ergänzt.

## 5. Empfohlene nächste Arbeitspakete

Diese Reihenfolge ordnet Arbeit innerhalb der bestehenden Abhängigkeiten; sie verschiebt
keinen Meilenstein und fügt keine neue Fähigkeit hinzu.

| Priorität | Arbeitspaket | Reviewbare Fertig-Bedingung |
|---|---|---|
| 1 | Sichtbare Persona-/Klon-Parität und erlaubte Persona-Information verbinden. | Mehrere gleiche Figuren können in einer echten Client-Szene verglichen werden; das Vertragsfeld zeigt nach erlaubter Freigabe dieselbe Persona. |
| 2 | Vorhandene Kampf- und Bewegungszustände darstellen. | Beobachter erkennen Beginn, Erfolg und Fehlschlag eines Kill-/Stun-/Lunge-Versuchs ohne Debug-Text. Keine Animation verändert das serverseitige Zeitfenster. |
| 3 | US-0071/0073: Ability-Slots aus der tatsächlichen Auswahl und Replikation versorgen. | Beide Plätze, Auswahl, Sperre und Cooldown stimmen mit dem Server überein; unbekannte Daten werden nicht geschätzt. |
| 4 | US-0075: die informationsgebenden Audio-Ereignisse hörbar machen. | Der Hinweis ist auch außerhalb des Blickfelds wahrnehmbar, mit vorgesehenem Caption-Kanal und gleicher Behandlung der Klone. |
| 5 | US-0078/0079/0077: Lobby, Match-Ende und Ergebnis als zusammenhängenden Ablauf schließen. | Eine kleine Gruppe kann starten, eine echte zeitlich begrenzte Runde beenden und das Ergebnis der Ereigniswertung sehen. |
| 6 | US-0098: moderierten Test mit Menschen durchführen. | Die Teilnehmenden können erklären, warum sie entdeckt wurden, warum sie Punkte erhielten und welche defensive Handlung möglich war. |

Neue Impulse für diesen Test: Jede Versuchsperson soll nach einer Begegnung zuerst die
eigene Erklärung geben, bevor Debug-Daten gezeigt werden. Ein technisch korrekter Ausgang,
den niemand erklären kann, ist ein Darstellungsbefund. Separat dieselbe Szene mit und ohne
HUD ansehen: Die Welt muss Absichten lesbar machen; das HUD darf Ursachen bestätigen,
aber keine ansonsten unsichtbaren Gegneridentitäten liefern.

## 6. Designentscheidungen, die offen bleiben

Mehr Referenznähe bedeutet nicht, jeden vorhandenen Unterschied stillschweigend zu löschen.

| Thema | Bestehende Grenze | Umgang |
|---|---|---|
| Porträt erst nach Lock | ASM-0030 schützt die zunächst unbekannte Persona. | Ein von Anfang an sichtbares Zielbild wäre eine eigene Entscheidung über die Informationsökonomie. Hier unverändert. |
| Verdacht bei verborgenem schnellen Bewegen | Die aktuelle Quellenberechnung koppelt Geschwindigkeit nicht an die Sicht eines Beobachters. | Den Unterschied in einer kontrollierten Begegnung untersuchen. Eine Sichtabhängigkeit berührt Designgesetz 1 und braucht eine explizite Entscheidung. |
| Mehrere Verfolger und Mehrfach-Fluchtboni | Der einzelne eingehende Vertragsrand ist ausdrücklich beschlossen. | Nicht als fehlendes MVP-Feature behandeln. |
| Cinderfall und Stun | Die vorhandene Fähigkeit hat eine bewusst abgegrenzte Wirkung. | Keine zusätzliche Betäubung als vermeintliche Korrektur ergänzen. |
| Contested Kill | ADR-0017 nennt die Abweichung zur gewünschten Referenz bereits als offen. | Keine Werte oder Regel entfernen, bevor der Owner den dokumentierten Punkt entschieden hat. |
| Streak-System | US-0099 ist post-MVP. | Die aktuelle Schleife zuerst prüfen; keine Scope-Erweiterung in diesem HUD-Pass. |

## 7. Dokumentationsschulden

Die entscheidungsrelevanten HUD-Stellen in UI_UX_SPEC, US-0073, US-0097 und dem
DECISION_LOG sind aktualisiert. Die lokale Testanzahl in CLAUDE.md ist ebenfalls korrigiert.

Außerhalb dieses Eingriffs bleiben veraltete Aussagen: ROADMAP beschreibt Lunge noch als
fehlenden Zustand; GLOSSARY bezeichnet implementierte Flucht-/Stagger-Funktionen als
ungebaut; GDD-06 und die DoD enthalten ältere Aussagen zur richtungslosen Warnung. In
GDD-07 stehen neben neueren Korrekturen noch alte Stun-/Escape-Vergleiche. Der README-
Statusblock nennt alte Story-, ADR- und Tunable-Anzahlen. Diese Stellen sollten gegen die
bereits beschlossenen ADRs und Ressourcen abgeglichen werden, nicht gegen Erinnerung.

Ein sinnvoller nächster Dokumentationsdurchgang trennt verbindliche Gegenwartsbeschreibung
von datierter Historie. Historische Entscheidungen bleiben erhalten, erhalten aber einen
eindeutigen Verweis auf ihre Ablösung. Ein Story-Status allein ersetzt diese Prüfung nicht.

## 8. Verifikation und Grenzen

| Prüfung | Ergebnis |
|---|---|
| Unit-Baseline | 192 Skripte; 1.651 bestanden, 8 pending/risky; keine fehlgeschlagenen Tests. |
| Unit nach Änderung | 193 von 193 Skripten; 1.663 Tests, davon 1.655 bestanden und dieselben 8 pending/risky; 29.712 Assertions. |
| Architektur nach Korrektur der Dokumentationsanzahl | 55 von 55 Skripten; 216 Tests bestanden; 1.235 Assertions. Kein Guard abgeschwächt. |
| Format | Gesamter Bestand: 532 GDScript-Dateien unverändert durch den Formatter. |
| Lint | `scripts/`, `test/`, `tools/` ohne Befund. |
| Repository-Guards | IP-Guard und Asset-Inventar bestanden über 1.624 versionierte Dateien; neue lokale Dateien zusätzlich separat auf gesperrte Begriffe geprüft. |
| Darstellung | Je 22 Zustände bei 1920×1080, 1280×720 und 2560×1080 aufgenommen. Repräsentative Grenzfälle visuell geprüft. |
| Textkontrast | Standardpalette im Ruhezustand gegen einen weißen Welthintergrund rechnerisch mindestens 7:1 für geprüfte normale Texte und negative Wertungen. Fade-Animationen und andere Paletten sind damit nicht zertifiziert. |

Die Aufnahmen liegen lokal unter `reports/hud-audit/`: `before/`, `1080p/`, `720p/`,
`ultrawide/`. Sie stammen aus der laufenden Client-Szene mit synthetischen HUD-Ereignissen.
Sie sind kein echter Multiplayer-Spieltest. Die Integration-Suite wurde für diesen
ausschließlich darstellenden Eingriff nicht erneut ausgeführt.

Bereits im Ausgangsstand bestehen acht offene Unit-Befunde, darunter das Crowd-Wire-Budget
mit etwa 101 statt 96 kbit/s und der geringe Effekt einer weiteren Cull-Radius-Senkung.
Die Crowd-Dichte dafür zu reduzieren wäre die falsche erste Maßnahme. Die Testausgabe
enthält außerdem bereits zuvor vorhandene Cleanup-/Resource-Meldungen; die Umgebung meldet
einen nicht lesbaren Zertifikatsspeicher. Diese Ausgaben sind nicht als neu behoben verbucht.

Die menschliche Lesbarkeitsprüfung, vollständige Animation-/Audio-Parität und die M6-
Spieltestkriterien bleiben offen. Dieser Bericht liefert keine Behauptung, dass das Spiel
bereits vollständig oder sein Balancing mit Menschen validiert sei.
