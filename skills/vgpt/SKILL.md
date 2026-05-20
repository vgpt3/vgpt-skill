---
name: vgpt-skill
description: Answer questions about Viewpoint Vista construction ERP data (jobs, cost, AP, AR, GL, payroll, equipment, etc.) using the VGPT MCP server. Use this skill whenever the user asks about Vista data, mentions a Vista module (JC, AP, AR, GL, PR, EM, PO, SL, SM, HQ, CM, IN, JB, MS, PM), references Vista tables or views (anything starting with b/v + 4 letters like bJCJM, vAPHB), asks for job cost / cost-to-date / WIP / retainage / certified payroll / AIA billing / pay-when-paid / lien waiver / subcontract data, or wants SQL against the Viewpoint database. ALSO use this when the user is working in Excel and references "vgpt" or asks construction-accounting questions that need live data — the Excel add-in benefits from this skill's disciplined tool sequencing because raw MCP calls can be flaky there. Do NOT use for general construction industry questions that don't require live Vista data, or for unrelated SQL Server work.
---

# vgpt-skill

Disciplined use of the VGPT MCP server to answer Viewpoint Vista questions reliably — especially from the Excel Claude add-in, where ad-hoc MCP calls tend to be inconsistent.

## Why this skill exists

The VGPT MCP server has a strict protocol baked into its tool descriptions, but those rules are easy to miss when Claude tries to "just use the tool" reactively. This skill makes the protocol explicit and front-loads the Excel-specific output conventions Aaron needs.

In short: **never freelance against Vista.** Use the documented tools in the documented order, label evidence, and format output for a spreadsheet.

## The protocol — every Vista question

### Step 0 — Bootstrap MCP discovery (first call only, especially in Excel add-in)

The VGPT MCP connection is unreliable when a conversation starts in the Excel Claude add-in. Symptoms: `tool_search` returns no VGPT MCP results, or only a partial subset of the 22 tools. There is also caching, so the first discovery attempt can come back stale even when the server is healthy.

**On the first Vista question of a conversation, before calling `ping`:**

1. Call `tool_search` with a VGPT-related query (e.g., `"vgpt viewpoint vista"`) to surface the connector and its tools.
2. Count the VGPT MCP tools returned. The server exposes **22 tools** in total. Seeing ~20+ is healthy.
3. If fewer than ~15 tools show up, retry `tool_search` with a different phrasing (e.g., `"viewpoint sql investigate"`, then `"job cost ap gl"`). The varied keywords help bypass the cache. **Cap at 3 attempts total.**
4. Once discovery looks healthy, proceed silently to Step 1 (ping). **Do not list the tools to the user** — that's noise. The user just wants their answer.
5. If after 3 attempts you still see fewer than ~15 tools, tell the user once, briefly:
   > VGPT MCP discovery is incomplete (only N of 22 tools visible). I'll try the ping anyway, but if it fails the connector may need a refresh from the add-in side.
   Then proceed to ping. Don't loop further.

**Skip Step 0 on subsequent Vista questions** in the same conversation — once the connection is warm, it tends to stay warm. Go straight to ping (or skip ping too if it was recent and successful).

### Step 1 — Always `ping` first

The `VGPT MCP:ping` tool is mandatory before any Vista answer. If it returns `status != "ok"` or fails to respond, **refuse** and tell the user:

> ⛔ vgpt3 MCP unavailable. Cannot answer Vista questions without validated corpus access. Restart the MCP server and resubmit.

Do **not** fall back to training knowledge. Vista's schema and business rules are bespoke; guessing is worse than refusing.

### Step 2 — `search_guides` before `investigate`

A lot of common questions have already been answered. Call `search_guides` with a short keyword query and optional `module` filter first. If you get a high-quality hit, present it (with citation) and stop. This saves tokens and is more accurate than re-deriving from schema.

### Step 3 — Use `investigate` as the primary entry point

`investigate` is the **preferred tool**. Do not write SQL directly first. `investigate` orchestrates table discovery, KB search, Crystal Report precedents, pre-validated SQL generation, and integrity-filter detection in one call. The SQL it returns has already passed `validate_and_fix_sql`.

**Mandatory arguments:**

- `question` — the user's natural-language question, verbatim or lightly cleaned
- `modules` — array of module codes you classified the question into. The tool **cannot** do this reliably on its own.
- `concepts` — array of multi-word construction/ERP domain phrases. The tool's keyword matcher splits questions into single words and misses compound terms.

**Set `is_reconciliation=true`** when the question involves subledger-to-GL ties, variance analysis, out-of-balance investigation, or "why doesn't X tie to Y" — even if the word "reconcile" isn't used.

### Step 4 — Triage and apply response_guidelines (don't blindly follow all of them)

The `investigate` response returns a `response_guidelines` array that is the **full set** of rules — typically 15–25 of them — but most are conditional on the question type or on specific fields being populated. Blindly emitting every section they require produces a bloated, confusing answer.

**Triage rule:** before responding, classify the user's question into one of these buckets and apply only the matching guidelines:

| Question type | Indicators | Apply guidelines about… |
|---|---|---|
| Documentation / concept | "how does X work", "where is X tracked", "what does X mean" | Citation, evidence tier, table description rules. **Skip** DQ advisory, recommendation_bullets, companion SQL, security-restriction template, advisory_context template. |
| Quantitative / reporting | "show me", "list", "aggregate", "by month", "by job" | Citation + DQ advisory + recommendation_bullets + dq_companion_sql + mandatory `Mth` filter + active-record filter rules. |
| Reconciliation | "tie to", "out of balance", "variance", "doesn't match" | All of the above + reconciliation 7-query protocol. Also pass `is_reconciliation=true`. |
| Security / restriction | "how do I restrict", "limit access to" | The full advisory template: Business Problem → How it Works → What Vista Cannot Do → Correct Approach with mapping → Implementation Steps → SQL A/B/C → Sources. |

Guidelines that reference fields not present in this response (e.g., `dq_companion_sql` is empty, `advisory_context` is null) **do not apply** even if listed.

**Other rules that always apply:**

- `confidence`: surface HIGH / MEDIUM / LOW to the user
- `evidence_summary.gaps`: call out gaps explicitly if non-empty
- KB articles have `fullContent`: use the actual procedure steps. Don't paraphrase form names or navigation paths.
- `gaap_relevant`: when non-empty, surface a brief GAAP advisory (e.g., "Retainage is GAAP-relevant — consult CPA for compliance").
- `unresolved`: list these as known limits of the answer so the user knows what wasn't traced.

### Step 4b — Trust hierarchy when fields disagree

The investigate response has multiple overlapping metadata fields and they sometimes contradict each other. Resolve conflicts this way:

- **Table role:** `schema_evidence[].business_purpose` is the preferred source, BUT it's often an empty string. When empty, fall back to: `behavioral_warnings` + `domain_warnings` + Crystal Report context, and label the description as `[SCHEMA]` evidence tier (not `[DOCUMENTED]`).
- **Tables actually queried:** trust the `FROM` / `JOIN` clauses in `sql_queries[].sql`, not the `tables_used` metadata field — they are known to disagree.
- **SQL relevance:** the SQL in `sql_queries` is a pre-validated *starting point* generated by the tool. It may be only loosely related to the user's question (e.g., a generic contract listing for a retainage question). Treat it as scaffolding, not the answer. Surface it only if it materially supports the response.

### Step 4c — De-duplicate before presenting

`prior_implementations`, `intelligence_findings`, and `search_guides` results frequently contain the same item repeated 2–4 times. Always de-dupe by `filename` or `title` before counting, citing, or showing to the user. Don't report "4 prior implementations found" when there's really one.

## Module taxonomy

Valid module codes (use these in `modules`):

| Code | Module | Code | Module |
|------|--------|------|--------|
| AP | Accounts Payable | JC | Job Cost |
| AR | Accounts Receivable | JB | Job Billing |
| CM | Cash Management | MS | Materials |
| EM | Equipment Management | PM | Project Management |
| GL | General Ledger | PO | Purchase Order |
| HQ | Headquarters (master data) | PR | Payroll |
| IN | Inventory | SL | Subcontract Ledger |
| | | SM | Service Management |

**Classification examples** (mirror these patterns):

- "How does pay when paid work?" → `modules=["SL","AP"]`, `concepts=["pay when paid","subcontract retainage"]`
- "Show me WIP aging by job" → `modules=["JC","GL"]`, `concepts=["work in progress","WIP aging","job cost"]`
- "Why is AP out of balance with GL?" → `modules=["AP","GL"]`, `concepts=["AP to GL reconciliation","posting variance"]`, `is_reconciliation=true`
- "Certified payroll report for Job 12345" → `modules=["PR","JC"]`, `concepts=["certified payroll","prevailing wage"]`
- "Equipment usage cost on this month's jobs" → `modules=["EM","JC"]`, `concepts=["equipment usage","cost allocation"]`

## Evidence labeling — no hedging

Every claim in the user-facing answer must carry an evidence tier:

- `[DOCUMENTED]` — direct quote or paraphrase from a KB article or support article. Always cite by title and article number, e.g. *"Misc Amount in AP Invoice Entry (000069739)"*.
- `[SCHEMA]` — inferred from table/column structure surfaced by the MCP tools.
- `[NOT-DOCUMENTED]` — no source found. Say so explicitly: "The repo does not document whether X applies to Y."

**Banned phrases** in user-facing answers: *generally, typically, usually, likely, probably, should, ought to, in most cases.* If you reach for one of these, you don't have evidence — say so plainly instead.

## SQL workflow (when you need to run a query directly)

If `investigate` doesn't fully answer the question and you need to run SQL:

1. `suggest_sql` — generates pre-validated SQL from a natural-language request. Returns aliases-removed, `WITH (NOLOCK)` SQL with base tables replaced by views.
2. `validate_and_fix_sql` — mandatory before `execute_sql`. This is non-negotiable; `execute_sql` only re-checks for DML, not the full security pipeline.
3. `check_sql_security` — flags secured-view joins and deprecated objects. Run it whenever the query touches HQCO, JCJM, JCCM, EMEM, or PREH.
4. `execute_sql` — runs the SELECT. Default 1000 rows, hard max 10000. **Not for bulk export** — large values are stringified.

**Quirks to remember:**

- Default DB is `Viewpoint`. Bare references like `bAPHB`, `vAPTH` resolve there.
- The `database` parameter on `execute_sql` is **ignored** — it only matters on corpus-selector tools.
- For system catalogs or cross-DB: use 3-part names like `[Viewpoint].sys.tables`.
- Deprecated: `DDSF` → use `DDVS`.

## Excel add-in output conventions

Aaron primarily uses this skill from the Excel Claude add-in. Format every answer for a spreadsheet user:

- **Lead with the answer**, not the methodology. One sentence headline, then evidence.
- **Tables in markdown** with explicit column headers — Excel parses these cleanly when pasted. Avoid merged cells, sub-headers, or visually fancy layouts.
- **SQL in fenced ```sql blocks** — one block per query, no inline SQL. Makes copy-paste reliable.
- **Numeric results**: keep raw values (no thousands separators inside the table — Excel handles formatting). State the unit/currency once above the table.
- **No long prose.** Aaron is looking at a sidebar in Excel, not reading a report. If something needs a paragraph, write three sentences max and offer to expand.
- **Cite at the end**, compact: `Sources: KB 000069739; investigate(modules=JC,AP)`. Don't bury citations inside the prose.

When a result would exceed ~50 rows, summarize and offer to export — don't dump 1000 rows into the chat.

## When MCP is flaky (the Excel add-in case)

If a tool call fails or returns nothing useful:

1. **Re-ping.** Confirm the server is still up. If not, refuse as per Step 1.
2. **Retry once** with the same args — transient failures are common.
3. **Reduce surface area.** If `investigate` is timing out, fall back to a tighter path: `search_guides` → `get_object_bundle` on a specific table → `suggest_sql`.
4. **Tell the user what happened** plainly: "The `investigate` call timed out after retry; here's what I got from `search_guides` instead." Don't paper over partial answers.

Never substitute training knowledge for a failed MCP call. Vista is too custom for that to be safe.

## Tool quick-reference

Primary path (use these 80% of the time):

- `ping` — liveness; mandatory first call
- `search_guides` — prior-answer lookup
- `investigate` — full investigation protocol (preferred entry point)

Targeted follow-ups:

- `search_objects` — find tables/views/procs by name or topic
- `get_object_bundle` — full knowledge bundle for a named DB object
- `get_field_profile` — data-quality profile for a single column
- `get_join_recipe` — validated join between two tables
- `get_constraint_chain` — full constraint inventory for a table
- `get_status_codes` — status-code definitions for a table
- `get_module_reference` — compiled docs for a module
- `get_domain_reference` — authoritative domain knowledge by topic
- `search_support_articles` — KB article search (8,199 articles + Vista docs)
- `search_reference_sql` — validated query patterns
- `search_implementations` — prior implementation work

SQL execution path:

- `suggest_sql` → `validate_and_fix_sql` → `check_sql_security` (if secured views) → `execute_sql`

Reporting:

- `list_report_templates` — available report templates
- `generate_report` — build a report from a business question
- `preview_dashboard` — preview Power BI dashboard for a query
