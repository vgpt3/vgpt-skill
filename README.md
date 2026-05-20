# vgpt-skill

A Claude skill for disciplined, reliable use of the **VGPT MCP server** when querying Viewpoint Vista construction ERP data. Solves the "MCP works but Claude doesn't use it well" problem with a structured protocol: connector bootstrap → ping → guide search → investigate → evidence-tiered citation → Excel-friendly output.

Especially helpful in the **Claude for Excel add-in**, where MCP connections can be unstable at conversation start.

**Project page:** [vgpt3.github.io/vgpt-skill](https://vgpt3.github.io/vgpt-skill) (landing page with one-click download — share this with users)

## What it does

- **Bootstraps the VGPT MCP connection** at conversation start (varied `tool_search` queries to bypass cache)
- **Enforces the documented MCP protocol**: `ping` → `search_guides` → `investigate` with mandatory `modules` + `concepts` classification
- **Labels every claim with an evidence tier** (`[DOCUMENTED]` / `[SCHEMA]` / `[NOT-DOCUMENTED]`); bans hedging language
- **Triages the 20+ response_guidelines** returned by `investigate` and applies only the ones relevant to the question type (documentation vs reporting vs reconciliation vs security restriction)
- **Formats output for Excel**: clean tables, fenced SQL blocks, compact end-citations, no long prose
- **Handles known quirks**: de-duplicates repeated results from `search_guides`/`prior_implementations`/`intelligence_findings`, falls back gracefully when `business_purpose` is empty, distrusts the `tables_used` metadata field in favor of actual SQL `FROM`/`JOIN` clauses

## Install

### Standard install (claude.ai — works for Excel, web, desktop, mobile)

**Skills are account-wide.** Install once at claude.ai and the skill is automatically available in every Claude surface signed into the same account — including the Claude for Excel / PowerPoint / Word add-ins. You don't need to install it separately in Excel.

1. **Download** the latest `.skill` file:

   [⬇️ Download vgpt-skill.skill (latest release)](https://github.com/vgpt3/vgpt-skill/releases/latest/download/vgpt-skill.skill)

2. **Open** [claude.ai](https://claude.ai) → click your profile → **Settings**

3. Go to **Capabilities** → **Skills** → click **Upload Skill** (or the `+` button) and select the downloaded file

4. Done. The skill is now active everywhere your account is signed in.

Make sure your **VGPT MCP connector** is also configured in **Settings → Connectors** — the skill assumes the MCP is reachable.

### Verify it's working

In a new conversation (Excel sidebar is fine), ask:

> What does retainage look like in Vista? Which tables?

The skill should auto-trigger, do the MCP connector bootstrap silently, and return a structured answer with evidence tiers (`[DOCUMENTED]` / `[SCHEMA]` / `[NOT-DOCUMENTED]`) and clean tables.

### For Claude Code users (terminal)

If your audience also uses the Claude Code CLI, they can install via plugin instead:

```bash
/plugin marketplace add vgpt3/vgpt-skill
/plugin install vgpt-skill@vgpt-skill-marketplace
/reload-plugins
```

Skill becomes available as `/vgpt-skill:vgpt`. Auto-update is opt-in via the `/plugin` UI.

### For enterprise (advanced)

If your org routes Claude for Excel through an LLM gateway (LiteLLM, Portkey, etc.), an admin can push this skill to all users via the bootstrap endpoint instead of requiring each user to upload manually. See [Anthropic's docs on bootstrap endpoints](https://support.claude.com/en/articles/13945233-use-claude-for-excel-powerpoint-and-word-with-third-party-platforms) for the spec.

## Versioning

- Releases follow `vMAJOR.MINOR.PATCH` (semver).
- Skill body changes that affect behavior bump MINOR; bug-fixes bump PATCH.
- Excel users: re-download the latest `.skill` to update.
- Claude Code users: enable auto-update on the marketplace, or `/plugin update vgpt-skill`.

### Releasing a new version

1. Bump version in `CHANGELOG.md` and any version refs.
2. `git tag v0.3.0 && git push --tags`
3. The Release workflow packages `vgpt-skill.skill` and publishes a GitHub Release.

## Project landing page (GitHub Pages)

This repo includes a single-file landing page at `docs/index.html` designed to be the shareable URL you give to users. It has the one-click download button, a brief explanation of the problem, and three-step install instructions.

**To publish it:**

1. Push the repo to GitHub
2. Repo Settings → **Pages** → Source: **Deploy from a branch**
3. Branch: `main`, folder: `/docs`
4. Save. Wait ~30 seconds.

Your landing page goes live at `https://vgpt3.github.io/vgpt-skill/`. Share that link instead of the GitHub releases page — the design is friendlier to non-technical users.

## License

MIT — see [LICENSE](./LICENSE).

## Contributing

Issues and PRs welcome. See [CHANGELOG.md](./CHANGELOG.md) for what's changed.
