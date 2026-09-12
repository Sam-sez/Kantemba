# Kantemba — Product Blueprint (v1)

## 1. Vision

Kantemba is a shop-management app for Zambian SMEs — a cash book, point-of-sale, and inventory tracker in one, built for traders who currently run their business on paper, memory, or nothing at all.

It replaces the mental load of pricing, change-calculation, and stock tracking, without requiring accounting knowledge, a data connection, or any extra hardware.

## 2. Target user

A shop owner or small trader in Zambia — retail, wholesale-adjacent, or informal trade — who:
- Handles cash and mobile money transactions daily
- Extends informal credit to regular customers
- Has a smartphone but unreliable or costly data
- Has no formal bookkeeping training

## 3. Core principles (non-negotiable for v1)

- **Offline-first.** The app must be fully usable with zero connectivity. No feature should require live internet to function. *(One deliberate exception, opt-in only: on an unrecognized barcode, if a connection happens to be available, Kantemba may silently try an online product-lookup to pre-fill the item name in the "New item" sheet. It never blocks or waits on this — with no connection, the sheet just opens blank as normal. Price and quantity are always entered manually regardless, since those are shop-specific.)*
- **No extra hardware.** Barcode scanning uses the phone's own camera. This is a deliberate moat — competitors assuming a paid barcode scanner unit exclude the majority of the target market.
- **ZMW only, English only.** No multi-currency, no localization, for v1.
- **Single shop per account.** No multi-location support in v1 — deliberately deferred to avoid overbuilding the data model before the core flows are proven.
- **Mobile money is a label, not a processor.** Kantemba never moves money. It only tags a transaction's payment method (Cash / Airtel Money / MTN MoMo) for record-keeping.
- **Built entirely from mobile, no PC.** The founder has no laptop. Every phase of this build — sandbox, coding, and deployment — must work from a phone. This shapes tooling choices in section 8.

## 4. Feature scope (v1)

### In scope
| Feature | Notes |
|---|---|
| Cash Book | Chronological ledger of every sale, purchase, and expense — dedicated Date, Details, Dr, Cr, and running Balance columns, filterable by time period and transaction type |
| New Sale | Camera barcode scan or manual item search → cart → change calculator → payment method tag. Unrecognized barcode → inline new-item creation. **Frequents** shortcut below Confirm for repeat non-barcoded items |
| Inventory | Barcoded and non-barcoded items, stock levels, cost/sell price, low-stock flagging. New items can also be created inline from New Sale or Outgoings when a scanned barcode isn't recognized |
| Outgoings | Tabbed screen — **Purchases** (scan/search → bulk-quantity entry → cost price → logs stock in; unrecognized barcode → inline new-item creation) and **Expenses** (category, amount, note). **Frequents** shortcut below Confirm on the Purchases tab |
| Creditors | Running-tab customer credit accounts. Credit sales log against a creditor (items, stock reduction, revenue recognized immediately) without touching the Cash Book. Payments and write-offs settle the balance; payments hit the Cash Book, write-offs hit Profit as a bad-debt expense |
| Charts & Reports | Weekly / monthly / annual views: revenue, product performance, profit |
| Dashboard | At-a-glance snapshot: today's sales, outstanding credit, low stock, recent transactions |
| Notifications | Low-stock alerts (extensible later) |
| Profile & Settings | Business info, data export/backup |

### Explicitly out of scope for v1 (revisit later)
- Multi-user staff accounts / permission levels
- Multi-shop support under one account
- Actual mobile money payment processing
- Local language support (Bemba, Nyanja, etc.)
- Cloud sync / multi-device access

## 5. Information architecture

**Top bar** (persistent): Profile · Creditors · Notifications
**Bottom nav** (persistent, 4 items): Charts · Cash Book · Inventory · Outgoings (Purchases + Expenses, tabbed)
**Floating action**: New Sale (always one tap away, sits above the bottom nav)

```
Dashboard (home)
├── Snapshot cards (scrollable): Today's Sales | Outstanding Credit | Low Stock
├── Recent Transactions (list) → See more → Cash Book
│
├── New Sale (floating button)
│   └── Opens directly into camera view (barcode targeting frame + scan line) → item auto-adds
│       to cart on scan with a toast + Undo (no per-scan confirm step, to keep continuous
│       scanning fast) → "Search instead" link toggles to a manual item list for non-barcoded
│       items or misreads → cart shown below with qty (+/-/manual) → payment method chip
│       (Cash / Airtel Money / MTN MoMo) → Cash shows amount-received + change; mobile money
│       hides both and shows a "paid in full, no change" note instead → confirm.
│       Unrecognized barcode → inline "New item" sheet (name, sell price, qty) instead of
│       an error → saves to Inventory and adds to cart in one step. Below Confirm: a
│       Frequents shortcut (top 10 by usage, qty stepper + Log per row) for fast repeat
│       entry of non-barcoded items.
│
├── Bottom nav
│   ├── Charts (weekly/monthly/annual, revenue, product performance, profit)
│   ├── Cash Book (full chronological ledger — Date/Details/Dr/Cr/Balance columns,
│   │   single filter button for time period + transaction type, filterable)
│   ├── Inventory (list, add/edit item, barcode or manual, low-stock flags)
│   └── Outgoings
│       ├── Purchases (scan/search → bulk-quantity entry → cost price → logs stock + cost.
│       │   Unrecognized barcode → inline "New item" sheet (name, cost, sell price, qty).
│       │   Below Confirm: Frequents shortcut, same pattern as New Sale, cost pre-filled
│       │   from last price paid and editable)
│       └── Expenses (category, amount, note, date)
│
├── Top bar
│   ├── Creditors
│   │   ├── List (zebra rows, name + phone, balance red if owing / green if settled,
│   │   │   filter: All / Owing / Paid / Written off)
│   │   ├── Search-or-create customer → scan/search item(s) → qty → Confirm logs a
│   │   │   credit Sale against that creditor's running tab (stock reduces, revenue
│   │   │   books immediately, appears in Recent Transactions — never in Cash Book)
│   │   └── Creditor detail (tap a row): contact info + balance up top, then a
│   │       chronological mini-statement of credit sales / payments / write-offs.
│   │       Two actions: Log Payment, Write Off — each a bottom sheet with
│   │       "Full remaining balance" or "Custom amount" → Confirm
│   ├── Notifications (low stock alerts)
│   └── Profile (business info → Settings → data export/backup)
```

## 6. Data model (draft)

**Item**
`id, name, barcode (nullable), cost_price, sell_price, stock_qty, low_stock_threshold, usage_count, created_at`

*`usage_count` increments each time the item is added to a sale or purchase (via scan, search, or Frequents) — it's what ranks the Frequents shortcut, and needs no manual input from the owner.*

**Sale**
`id, timestamp, total_amount, amount_received, change_given, payment_method [cash|airtel_money|mtn_momo|credit], creditor_id (nullable)`

*A credit sale is a normal `Sale` (payment_method: `credit`, `creditor_id` set) — it reuses the same `SaleLineItem` rows, so stock reduces and revenue books to Charts exactly like a cash sale, and it surfaces in Recent Transactions the same way. The only thing that changes is the Cash Book, which excludes any `Sale` with `payment_method: credit` since no cash or cash-equivalent moved.*

**SaleLineItem**
`id, sale_id, item_id, quantity, unit_price_at_sale`

**Purchase**
`id, timestamp, total_amount, supplier (nullable), payment_method`

**PurchaseLineItem**
`id, purchase_id, item_id, quantity, unit_cost_at_purchase`

**Expense**
`id, timestamp, category [rent|transport|airtime|other], amount, note`

**Creditor**
`id, name, phone (nullable), amount_owed, status [open|partial|paid|written_off], created_at`

*A running tab: `amount_owed` accumulates across every credit `Sale` linked to this creditor, and decreases with each `CreditorPayment` or `CreditorWriteOff` against it. `status` is `written_off` only when `amount_owed` reaches zero specifically because a write-off (full or the last partial write-off) closed out the remaining balance — if any balance remains after a partial write-off, the creditor stays `open`/`partial` and the card remains active, not archived.*

**CreditorPayment**
`id, creditor_id, amount, timestamp`

*Reduces `amount_owed`. Recorded as a Cash Book receipt (cash in) — its own type bucket, separate from Sales, so debt collection never gets counted as new revenue.*

**CreditorWriteOff**
`id, creditor_id, amount, timestamp, note (optional)`

*Reduces `amount_owed` like a payment, but no cash moved — excluded from the Cash Book, same rule as a credit sale. Recognized as a bad-debt expense in Charts' Profit calculation (Profit = Revenue − Cost of goods − Expenses − Write-offs), since the revenue was already booked at the time of the credit sale and is now being accepted as uncollectible. Can be partial or full, same "custom amount" mechanism as a payment.*

**Business** (single record for v1)
`id, business_name, owner_name`

*Note: the Cash Book's per-row Date/Time and running Balance columns are computed from each record's existing `timestamp` field — no schema changes were needed to support the redesign.*

## 7. Design system

**Color tokens**
| Token | Hex | Use |
|---|---|---|
| Background | `#0C100D` | App background |
| Card | `#171D19` | Elevated surfaces |
| Row alt (zebra) | `#1C2320` | Alternating ledger row background — subtle, on-theme, not a hard contrast |
| Green (primary) | `#3EA35C` / `#4CBE6C` | Primary actions, positive amounts, Sales (`#3EA35C`) / Creditor Payments (`#4CBE6C`, bright variant — same "cash in" family, visually distinct in Cash Book) |
| Red (alert) | `#E2542D` | Low stock, overdue credit, Expenses |
| Blue (info) | `#3E8ED8` | Purchases, secondary tags |
| Text primary | `#F4F6F4` | Headlines, values |
| Text secondary | `#8FA095` | Labels, meta text |

**Type**: One bold system-font stack (Inter), heavy weights (800–900) for numbers/headers, 600 for body. No decorative all-caps labels or eyebrow text. Numeric columns use tabular figures (`font-variant-numeric: tabular-nums`) so amounts align vertically — important for ledger trustworthiness.

**Icons**: Solid/filled style throughout, for fast at-a-glance recognition over refinement.

**Interaction pattern (New Sale)**:
- Opens directly into a simulated/real camera view — scanning is the primary action, not something tapped into.
- A targeting frame (corner brackets, sized for a barcode's proportions) plus a moving scan line signal the camera is actively searching.
- On successful scan, the item auto-adds to the cart immediately — no per-scan confirm modal. Speed for continuous scanning was prioritized over a hard stop on every item; misreads are caught via a toast with an **Undo** action, or by glancing at the running cart.
- "Search instead" is a small, secondary link (not a competing button) for non-barcoded items or when a scan isn't cooperating. Manually-searched items are added identically to scanned ones — same toast, same cart row, same qty controls — so the mental model doesn't change based on how an item entered the cart.
- Quantity: default 1 on add → `+` / `−` steppers for quick adjustment → tap-to-type for manual/bulk entry. The tappable number has a dashed underline at rest and a solid green underline while being edited, so it reads as editable rather than a static label — this convention is used everywhere quantity appears in the app.
- Payment method is chip-selected (Cash / Airtel Money / MTN MoMo) **before** the amount fields, since it determines what's shown next: Cash reveals amount-received and change; mobile money hides both entirely and shows a short "paid in full — no change to calculate" note, since no physical cash changes hands.
- **Unrecognized barcode**: if a scan matches nothing in Inventory, instead of an error a **"New item"** bottom sheet opens with the barcode pre-filled — name, sell price, and quantity received. Confirming saves it to Inventory and adds it to the current cart in the same motion, no separate trip to the Inventory screen. This same sheet (via the identical mechanism) is how a shop owner populates their entire stock list on day one — scan-and-create is both the onboarding flow and the ongoing new-item flow.
- **Frequents**: a shortcut section sits directly below the Confirm button, reached by scrolling — not a toggle or a hidden link. It lists the top 10 items by `usage_count`, each row showing name, a qty stepper, and a **Log** button that adds it to the cart immediately (qty resets to 1 after). This exists specifically for shops with many non-barcoded items sold repeatedly (e.g. a bakery's scones, cream pies, cupcakes) where searching by name every time would be tedious. List has a capped visible height (~4–5 rows) with internal scroll so it never pushes the cart or Confirm button off-screen. Camera-first behavior is unaffected — Frequents is entirely below the fold until scrolled to.

**Interaction pattern (Cash Book)**:
- Laid out as a true accounting ledger, not a generic transaction list: dedicated **Date** column (date + timestamp per row, since a shop can log several transactions in the same day), **Details**, **Dr**, **Cr**, and a running **Balance** column — modeled directly on a real institutional cash book/statement layout.
- An **Opening balance** band sits above the first row, and the balance carries forward row by row rather than resetting per screen or per day.
- Filtering is a single **Filter** button (not permanently-visible chip rows) that opens a dropdown with two independent sections: **Time period** (Today / This week / This month / This year / All time) and **Show** (All transactions / Sales / Purchases / Expenses / Creditor Payments). The two combine — e.g. "This month · Purchases."
- Type options in the filter are color-coded with a small dot (green = Sales, blue = Purchases, red = Expenses, bright green = Creditor Payments), reusing the same color semantics as the rest of the app rather than introducing new meaning. Creditor Payments gets its own bucket rather than folding into Sales, so debt collection never inflates the Sales figure — Details column reads e.g. "Payment received — J. Banda" so it's unambiguous even in the combined "All transactions" view.
- Credit sales never appear in the Cash Book at all — no cash or cash-equivalent moved, so there's nothing to log here. They still appear in Recent Transactions on the Dashboard, and in Charts as revenue, via the underlying `Sale` record.
- When a type filter narrows the view to one side of the book, the Balance column relabels itself (e.g. "Sales") and tracks a running total of just that type, rather than showing a Dr-minus-Cr figure that would no longer represent the shop's actual cash position.
- Rows alternate between the card color and a barely-lighter shade (zebra striping) to aid line-tracking across the row, deliberately subtle rather than a hard-contrast stripe — no borders needed between rows as a result.

**Interaction pattern (Outgoings)**:
- Single screen, two tabs (Purchases / Expenses) — one bottom-nav slot, not two, consistent with the 4-item nav constraint.
- **Purchases**: scan or search selects an item, then a bottom-sheet prompt asks for **quantity and cost per unit before adding to cart** — unlike New Sale's auto-add-1, since restocking is typically bulk (a case, a carton) rather than one unit at a time. The quantity control reuses the same +/− steppers and tap-to-type as New Sale, with the same dashed/green-underline editability cue. Supplier is an optional field. Cart rows keep their own steppers for later adjustment. No change calculator (not applicable to purchases).
- **Unrecognized barcode** (Purchases): same "New item" sheet as New Sale, with cost price added alongside name, sell price, and quantity received — since a purchase is establishing that item's cost for the first time. Saves to Inventory and adds to the current purchase in one step.
- **Frequents** (Purchases only — not applicable to Expenses): identical placement and mechanism to New Sale — below the Confirm button, top 10 by `usage_count`, qty stepper + Log per row, capped height with scroll. Difference from New Sale's version: the row also shows and pre-fills **cost per unit from the last price paid**, editable in case this delivery's price changed, so a routine restock is qty confirm → Log, cost already correct most of the time.
- **Expenses**: no cart, scanning, or Frequents — a flat form (category chips, amount, optional note). Category chips use the app's red (Expenses' semantic color) when selected.
- Neither tab keeps a visible log or list after an entry is saved — logging is a write-only action here. Confirmed entries land in the Cash Book (Purchases = blue Cr, Expenses = red Cr) and, for Purchases, update Inventory stock — that's where the record lives, so Outgoings itself just resets and is ready for the next entry.

**Interaction pattern (Creditors)**:
- **List screen**: zebra-striped rows (same card + alternating-row treatment as Cash Book/Outgoings) — each row shows name, phone as secondary text, and the balance amount in **red if owing** (open/partial) or **green if settled** (paid/written_off), reusing the existing red = "overdue credit" token from the color table rather than introducing a new one. A single **Filter** button, same pattern as Cash Book, narrows to All / Owing / Paid / Written off.
- **Adding a credit sale**: tapping Creditors offers search-or-create for the customer — search by name/phone to find an existing running tab, or add a new name inline — mirroring the same search-or-create pattern already used for items. Once a customer is selected, item entry (scan or search, qty steppers, tap-to-type) works identically to New Sale, minus the payment-method chip and change calculator, since the payment method is implicitly credit. Confirming creates a `Sale` (payment_method: credit) against that creditor's tab: stock reduces immediately, revenue books to Charts immediately, the transaction appears in Recent Transactions — and nothing is written to the Cash Book, since no cash changed hands.
- **Running tab**: a creditor accumulates balance across multiple credit sales over time rather than closing out after one purchase — this matches how informal shop credit actually works (a regular customer's tab grows between payments), and means `amount_owed` is simply the sum of their outstanding credit sales minus whatever's been paid or written off.
- **Creditor detail** (tap a row): contact info and the current balance sit at the top, followed by a chronological mini-statement mixing three entry types — credit sales (cart icon, items + amount), payments (cash icon, amount), and write-offs (struck-through amount, red) — so the full history of the relationship is readable without leaving the screen.
- **Settling a balance**: two actions on the detail screen, **Log Payment** and **Write Off**, each opening a bottom sheet with the same two options — "Full remaining balance" or a custom amount — then Confirm. A payment creates a `CreditorPayment` and lands in the Cash Book as a receipt (its own bucket, not counted as Sales). A write-off creates a `CreditorWriteOff`, never touches the Cash Book, and is recognized as a bad-debt expense that reduces Profit in Charts.
- **Status logic**: `status` only flips to `written_off` when `amount_owed` reaches exactly zero because a write-off closed it out — a partial write-off that still leaves a balance keeps the creditor `open`/`partial` and the card stays active in the default list view, it doesn't get archived early.
- The **Dashboard's "Outstanding Credit"** snapshot card sums `amount_owed` across every `open`/`partial` creditor — written-off balances no longer count as expected cash once settled that way.

**Interaction pattern (Charts)**:
- Top bar is minimal — back chevron, "Charts" title with a trending-up icon in bright green, no clutter — since the screen's own headline number is the focal point, not the chrome.
- A single **headline metric** sits at the top (Revenue by default, or the selected type) labeled with the active period, e.g. "Revenue · This Month." For the "All" type view it shows a period-over-period **delta** (▲/▼ percentage vs. the immediately preceding period of equal length) in green or red — omitted for single-type views (Sales/Purchases/Expenses) where a direct comparison figure isn't the headline's job.
- **Period tabs** (Today / This Week / This Month / This Year / All time) are a horizontally scrollable pill row, consistent with the tab pattern used elsewhere in the app rather than a dropdown — Charts is a browsing screen, so period switching should be one tap, not two.
- The **trend chart** is a smooth area chart with a color-matched gradient fill (fading to transparent) rather than a hard-edged bar chart — reinforces the "flowing ledger" feel established in Cash Book. Y-axis is minimal (no axis line, small muted tick labels); X-axis is unlabeled except for three date markers (start / mid / end) below the chart, keeping the plot area uncluttered on a small screen. Dense periods (e.g. "All time" across a year of daily data) are downsampled for legibility rather than rendering every point.
- **Stat callouts** — Best Day, Profit, Avg Sale Value — sit directly beneath the chart as three equal-width columns, giving an at-a-glance read before the person even scrolls to the breakdowns. Profit renders in red if negative for the period, otherwise in standard text-primary (not green) — matches the app's existing pattern of only using green for explicit "good/sales" semantics, not every positive number.
- **Type filter** is a segmented control (All / Sales / Purchases / Expenses) with the same color-coded dots used in the Cash Book filter — green/blue/red — reusing that semantic mapping rather than introducing a new one. Switching type re-colors the chart's line/fill and re-scopes the headline metric and trend data to that type only.
- **Product performance** is a 2×2 stat grid (Items sold, Transactions, Top product, Profit margin) followed by a **full ranked list "By revenue"** — same card + zebra-row treatment as Cash Book and Outgoings — so product-level detail is available without a separate screen.
- All monetary values use the same `K` + tabular-nums formatting as the rest of the app, so figures line up and read consistently between Charts, Cash Book, and Outgoings.
- *Note: Charts is derived from Sale/SaleLineItem/Purchase/Expense records, plus `CreditorWriteOff` for Profit only (Profit = Revenue − Cost of goods − Expenses − Write-offs) — credit sales already count as Revenue via their underlying `Sale` record, so write-offs are the one additional input Profit needs to stay accurate when a debt goes bad.*

**Interaction pattern (Profile / Settings)**:
- **Profile** is the business's all-time snapshot, distinct from Dashboard's "today" focus. Identity block up top: logo placeholder, business name, owner name as subtitle, "Business since [created_at]." A single **Edit business info** button opens a bottom sheet (name, owner, phone) with Cancel/Save — no inline editing on the screen itself.
- **Stats row** (horizontally scrollable cards): Total Sales (all-time revenue), Items Tracked (inventory count), Outstanding Credit (red, sum of open/partial creditor balances) — "View All" links to Charts.
- **Recent Activity** is a condensed 5-row feed reusing the same color-coded type icons as the rest of the app (green = Sale, blue = Purchase, red = Expense, bright green = Creditor Payment) — "View All" links to Cash Book.
- **Settings** is reached via the gear icon on Profile's top bar. Grouped into: **Business** (read-only summary of name/owner), **Inventory** (low-stock threshold default, a stepper applied to newly created items), **Notifications** (low-stock alert toggle), **Data** (export/backup, and reset-all-data behind a destructive confirm sheet that explains exactly what's deleted and recommends backing up first), **About** (currency and language shown as fixed/non-editable — ZMW and English are locked for v1 per section 3 — plus app version).

## 8. Tech stack

**Phase 0 — Sandbox (this chat)**: React, in-browser, persisted via a simple key-value store, used to validate flows and UI before any native commitment.

**Phase 1 — Production app**: Flutter.
- Single codebase for Android + iOS (Android is the priority market)
- Strong offline-first support via local database (e.g. `sqflite` or `hive`)
- Mature camera-based barcode scanning packages (e.g. `mobile_scanner`) — no external hardware
- Compiles to an installable APK for informal distribution, ahead of or alongside a Play Store listing

**Tooling for a PC-less workflow**: all development happens in a cloud environment, accessed entirely from a phone.
- Primary: **Claude Code via the Claude mobile app** — cloud-based coding environment; handles writing the Flutter code, installing the SDK, building the APK, and pushing to GitHub, with no local machine involved
- Fallback: **GitHub Codespaces** — full cloud dev environment accessible from a mobile browser, tied directly to a GitHub repo
- End result either way: source code lives on **GitHub**, and the built APK is delivered as a downloadable file — no compiling ever happens on the founder's own device

## 9. Build phases

1. **Sandbox prototype** — validate Dashboard, New Sale, Inventory, Cash Book flows end-to-end with realistic sample data, built and reviewed entirely in chat
2. **Iterate** — incorporate new ideas/changes cheaply while still in the sandbox
3. **Move to Claude Code (mobile app)** — set up a cloud coding environment and GitHub repo, still no PC required
4. **Flutter build** — port validated flows and data model into the real, deployable app
5. **Internal testing** — real shop, real data, real edge cases (till float mismatches, partial payments, damaged/returned stock)
6. **Deployment** — APK distribution first, Play Store listing once stable

## 10. Sandbox progress

Tracks what's been built and approved in the Phase 0 sandbox, so this stays a living reference rather than drifting from the actual prototype.

| Screen | Status |
|---|---|
| Dashboard | Built — snapshots, recent transactions, live updates |
| New Sale | Built & approved — camera-first scan, undo-on-add, payment-aware checkout, inline new-item creation on unrecognized barcode, Frequents shortcut below Confirm |
| Inventory | Built — search, low-stock flagging, add item |
| Cash Book | Built & approved — true ledger layout (Date/Time, Details, Dr, Cr, running Balance columns), single filter button (time period + transaction type dropdown), zebra-striped rows |
| Charts | Built & approved — headline metric with period-over-period delta, 5-way period tabs (Today/Week/Month/Year/All time), area chart with type-colored gradient fill, segmented Sales/Purchases/Expenses filter reusing Cash Book color semantics, Best Day / Profit / Avg Sale Value callouts, product performance stat grid, full by-revenue product list |
| Outgoings (Purchases + Expenses) | Built & approved — bulk-quantity entry on Purchases (qty + cost prompt before cart add), inline new-item creation on unrecognized barcode, Frequents shortcut (cost pre-filled from last price) below Confirm, category-chip Expenses form, no redundant in-screen list on either tab |
| Creditors | Spec locked, not yet built — running-tab credit accounts (data model + interaction pattern in sections 6–7), reachable from top bar |
| Profile / Settings | Built & approved — Profile: business identity block, Edit sheet, Stats cards (Total Sales/Items Tracked/Outstanding Credit), Recent Activity feed. Settings: business info, low-stock threshold default, low-stock alert toggle, export/backup + reset-data (with confirm sheet), fixed currency/language, version |

## 11. Open questions for later phases

- Backup format: CSV export, PDF summary, or both?
- At what point (if any) does multi-shop support get prioritized?
