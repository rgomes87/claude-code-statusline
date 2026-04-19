# claude-code-statusline

A colourful, information-dense 4-line status line for [Claude Code](https://claude.ai/code), built as a bash script.

## Preview

```
❮■■□□□□□□□□❯   20%  ⬇ 447 ⬆ 10.8k
Sonnet 4.6 · high ∷ …/tmp/claude-code-statusline  ⎇ main
● 5h ▮▮▮▮▮▮▮▮▮▯ 90% ⏱ 0h 46m
◕ 7d ▮▮▮▮▮▮▯▯▯▯ 60% ⏱ 4d 5h
```

**Line 1 — Context window**
- 10-cell gradient bar (green → yellow → orange → red) with `■`/`□` squares
- `❮`/`❯` brackets colour-matched to the percentage urgency
- Percentage fixed-width (3 chars) so token counts don't shift
- Token counts: ⬇ input / ⬆ output

**Line 2 — Session info**
- Active model and effort level, separated from location by `∷`
- Current working directory (truncated to last 2 components)
- Git branch with status: `✎N` dirty files · `↑N` ahead · `↓N` behind

**Line 3 — 5-hour rate limit**
- Shown as **remaining** capacity (starts full, drains to empty)
- Circle icon: `●` > 75% · `◕` > 50% · `◑` > 25% · `◔` > 0% · `○` empty
- `▮`/`▯` bar drains green → red as allowance is consumed
- Inline reset countdown (`⏱`)

**Line 4 — 7-day rate limit**
- Same format as line 3, always on its own line for easy scanning

---

## Requirements

- **Claude Code** (CLI, desktop, or IDE extension)
- `bash`
- `jq` — for parsing the JSON Claude Code sends to the script
- `python3` — for token formatting and reset countdown calculation
- `git` — for branch and status info

Install `jq` if needed:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

---

## Install

**1. Download the script**
```bash
curl -o ~/.claude/statusline.sh \
  https://raw.githubusercontent.com/rgomes87/claude-code-statusline/main/statusline.sh
```

**2. Make it executable**
```bash
chmod +x ~/.claude/statusline.sh
```

**3. Add to `~/.claude/settings.json`**

Merge the following into your existing `~/.claude/settings.json` (create the file if it doesn't exist):
```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/YOUR_USERNAME/.claude/statusline.sh",
    "padding": 2
  }
}
```
Replace `YOUR_USERNAME` with your macOS username, or use the full path from `echo ~/.claude/statusline.sh`.

**4. Restart Claude Code** — the status line appears at the bottom of the terminal.

---

## Customisation

**Colours** — The script uses [256-colour ANSI codes](https://www.ditig.com/publications/256-colors-cheat-sheet). Change any `c 82` style call to a different colour number.

**Context bar width** — Change `BAR_WIDTH=10` to any value.

**Effort level** — The script reads `effortLevel` from `~/.claude/settings.json` automatically. Set it there and it shows on Line 2.

**Rate limit bars** — The mini bars are 10 cells wide (`width=10` in the rate bar loops). Adjust to taste.

---

## How it works

Claude Code calls the script on every prompt update, piping a JSON object to stdin. The JSON contains context window usage, rate limit data, model info, and workspace path. The script parses this with `jq`, builds coloured ANSI output, and prints up to 4 lines that Claude Code renders in the status area.

The script is stateless — no files written, no background processes.

---

## License

MIT
