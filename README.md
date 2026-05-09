# model-agent-status

A compact Claude Code statusline for GitCode-hosted model work.

It renders the active model, context usage, directory/git branch, session age, GitCode token usage, and mo-fix-agent remaining time.

## Install

From GitHub:

```bash
npx -y --package github:JiashuaiXu/model-agent-status model-agent-status
```

From a local checkout:

```bash
node bin/install.js
```

The installer copies `bin/statusline.sh` to `~/.claude/statusline.sh` and sets:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\""
  }
}
```

## Requirements

- `bash`
- `jq`
- `curl`
- `git`

## GitCode Cookie

GitCode API calls require a valid web session cookie. Prepare it before expecting the token and agent lines to render:

```bash
mkdir -p ~/.claude
$EDITOR ~/.claude/.gitcode_session_cookie
chmod 600 ~/.claude/.gitcode_session_cookie
```

Paste only the raw `Cookie` request-header value into that file. You can copy it from browser DevTools, or export it with a browser extension such as J2TEAM Cookies (`j2team_cookies`).

Full setup and validation guide:

- [docs/GITCODE_COOKIE.md](docs/GITCODE_COOKIE.md)

Override the path if needed:

```bash
export GITCODE_COOKIE_FILE=/path/to/cookie
```

## Output

First line:

```text
MoonshotAI/Kimi-K2.6 | ctx 42% | repo main* | 1h08m | plan
```

GitCode lines:

```text
tokens ●●●○○○○○○○ 32% 640.0k/2.0M
agent  ●●●●●●●○○○ 2h09m left until 07:00
```

If `can_renewal=true`, the agent line adds `renew`.

## API Sources

- token usage: `GET https://web-api.gitcode.com/widget/api/v1/token_usage`
- agent detail: `GET https://web-api.gitcode.com/aihub/api/v1/mo-fix-agent/detail`

Responses are cached for 60 seconds under:

```text
/tmp/claude/model-agent-status/
```

## Refresh Timing

The statusline is called frequently by Claude Code, so GitCode API responses are cached. The default cache TTL is 60 seconds.

Change it with:

```bash
export MODEL_AGENT_STATUS_CACHE_TTL=120
```

Set it to `0` while debugging to fetch fresh data on every render:

```bash
MODEL_AGENT_STATUS_CACHE_TTL=0 bash ~/.claude/statusline.sh
```

## Credits

This project was built with reference to [`nilbuild/claude-statusline`](https://github.com/nilbuild/claude-statusline), an MIT-licensed Claude Code statusline by Kamran Ahmed. See [NOTICE.md](NOTICE.md).

## Configuration

| Variable | Default |
| --- | --- |
| `GITCODE_COOKIE_FILE` | `~/.claude/.gitcode_session_cookie` |
| `MODEL_AGENT_STATUS_CACHE_DIR` | `/tmp/claude/model-agent-status` |
| `MODEL_AGENT_STATUS_CACHE_TTL` | `60` |
| `GITCODE_TOKEN_USAGE_URL` | GitCode token usage endpoint |
| `GITCODE_AGENT_DETAIL_URL` | GitCode mo-fix-agent detail endpoint |

## Uninstall

```bash
npx -y --package github:JiashuaiXu/model-agent-status model-agent-status --uninstall
```

From a local checkout:

```bash
node bin/install.js --uninstall
```
