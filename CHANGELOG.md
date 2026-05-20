# Changelog

All notable changes to vgpt-skill are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

## [0.3.0] — 2026-05-19

### Added
- **Step 0 — MCP bootstrap protocol.** On first Vista question of a conversation, run varied `tool_search` queries (cap 3 attempts) to warm the VGPT MCP connection before pinging. Specifically addresses the Excel add-in's startup instability.
- **Triage table for `response_guidelines`.** The `investigate` tool returns 15–25 conditional guidelines; the skill now classifies the question type (documentation / reporting / reconciliation / security) and applies only the relevant subset, preventing bloated responses.
- **Trust hierarchy for conflicting metadata.** Explicit fallback when `schema_evidence.business_purpose` is empty, and a rule to trust SQL `FROM`/`JOIN` clauses over the `tables_used` metadata field when they disagree.
- **De-duplication rule** for repeated entries in `intelligence_findings`, `prior_implementations`, and `search_guides`.

## [0.2.0] — 2026-05-19

### Added
- Module taxonomy table (15 modules: AP, AR, CM, EM, GL, HQ, IN, JC, JB, MS, PM, PO, PR, SL, SM)
- Five classification examples for `modules` + `concepts` argument construction
- Evidence labeling system (`[DOCUMENTED]` / `[SCHEMA]` / `[NOT-DOCUMENTED]`)
- Banned-phrase list (no "generally", "typically", "usually", "likely", etc.)
- Excel-friendly output conventions (lead with answer, compact citations, no merged cells)
- MCP-flaky fallback strategy (re-ping → retry once → reduce surface area → tell user plainly)

## [0.1.0] — 2026-05-19

### Added
- Initial skill: mandatory `ping`, `search_guides` before `investigate`, full SQL workflow (`suggest_sql` → `validate_and_fix_sql` → `execute_sql`), security awareness (HQCO/JCJM/JCCM/EMEM/PREH), deprecated-object handling (DDSF → DDVS).
