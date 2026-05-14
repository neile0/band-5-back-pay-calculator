# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A single-page Flutter web calculator for NHS Scotland Band 5 AfC (Agenda for Change) back pay. Staff enter their spine point, contracted hours, and the period when they were still on the old pay rate. The app estimates gross and net back pay using published NHS Scotland pay scales and Scottish income tax / NI rates.

## Commands

```bash
make dev        # Flutter hot-reload dev server at http://localhost:8080
make up         # Build and run production Docker container at http://localhost:80
make down       # Stop Docker container
make build      # Rebuild Docker image
make logs       # Tail Docker logs
make analyze    # fvm flutter analyze
make test       # fvm flutter test
```

Always use `fvm flutter` / `fvm dart`, never the global `flutter` command.

## Architecture

Single-page app — no routing, no backend, no Riverpod. A single `StatefulWidget` (`CalculatorPage`) owns all state.

```
lib/
├── main.dart                    # App entry, MaterialApp theme
├── calculator_page.dart         # Entire UI — one StatefulWidget
└── domain/
    ├── pay_scales.dart          # NHS Scotland Band 5 salary constants (2024/25–2026/27)
    ├── tax.dart                 # Scottish income tax, NI, NHS pension functions
    └── calculator.dart          # calculateFromScales() / calculateFromHmrc() pure functions
```

## Domain Data

**NHS Scotland Band 5 annual FTE salaries:**

| Year    | Entry   | Intermediate | Top     | FTE hrs |
|---------|---------|-------------|---------|---------|
| 2023/24 | £30,229 | £32,300     | £37,664 | 37.5    |
| 2024/25 | £31,892 | £34,077     | £39,735 | 37.5    |
| 2025/26 | £33,247 | £35,525     | £41,424 | 37.5    |
| 2026/27 | £34,494 | £36,857     | £42,977 | 36.0    |

FTE changes from 37.5 → 36.0 hours in 2026/27 due to NHS Scotland reduced working week (effective April 2026).

Tax rates in `tax.dart` use Scottish income tax bands for 2025/26 as a reasonable approximation across all years.

## Two Calculation Modes

- **Pay scales** — user picks years and the date window when they were still on the old rate; back pay = (new - old) × hours_ratio × period_ratio
- **HMRC earnings** — user enters gross earnings from the HMRC app; back pay = max(0, expected_new_rate - actual_hmrc_earnings)
