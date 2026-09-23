# Flux

A lightweight iOS bookkeeping app for income and expense tracking, trend analysis, category management, and CSV import/export.

## Features

- Three-tab layout: Ledger, Trend, Manage
- Entry fields: category, amount (one decimal place), time
- On launch, focuses the amount field and shows the keyboard
- Hides the bottom tab bar while the keyboard is visible; a top-trailing `+` returns to the ledger input quickly
- Trend chart: daily / monthly / yearly bar charts for income, expense, and balance
- Manage: maintain income and expense categories (emoji + name)
- CSV export of all entries and CSV import to replace records

## CSV import and export

### Export

- UTF-8 text, comma-separated.
- Header row (first line): `id,type,categoryName,amount,time`
- One record per line after the header.
- `type`: `income` or `expense` (matches `RecordType` raw values).
- `amount`: one decimal place (e.g. `12.5`).
- `time`: ISO 8601 datetime (as produced by `ISO8601DateFormatter`), including date and time.
- `categoryName`: wrapped in double quotes; any `"` inside the name is escaped as `""`.

### Import

- **Replaces all ledger records** with successfully parsed rows from the file. Rows that fail validation are **skipped** (partial import with no per-row error UI).
- The **first line is always treated as a header and is not imported**, even if it does not match the column names below—include a header line and put data starting on line 2.

**Preferred layout (with stable ids)** — 5 columns after the header:

| Column | Description |
|--------|-------------|
| `id` | UUID string |
| `type` | `income` or `expense` |
| `categoryName` | Category label; use quotes if it contains commas |
| `amount` | Numeric; parsed as `Double`, stored rounded to one decimal |
| `time` | ISO 8601 string that `ISO8601DateFormatter` can parse (use an exported file as a template) |

**Without `id`** — 4 columns: `type`, `categoryName`, `amount`, `time` (new UUIDs are assigned).

**Legacy layouts** (still accepted):

- 5 columns when the first field is **not** a UUID: `type`, `categoryEmoji`, `categoryName`, `amount`, `time` (emoji column is ignored).
- 6+ columns: `id`, `type`, `categoryEmoji`, `categoryName`, `amount`, `time` (emoji column is ignored).

Parsing uses the same quoted-field rules as export: commas inside a field require wrapping the field in `"`, and `"` inside a field is doubled.

## Tech

- SwiftUI
- Swift Charts
- FileImporter / FileExporter
- Local JSON under Application Support (`records.json`, `categories.json`); legacy UserDefaults keys are migrated once on first launch
