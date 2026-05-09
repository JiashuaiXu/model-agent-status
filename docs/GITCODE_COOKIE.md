# GitCode Cookie Setup

`model-agent-status` reads GitCode API data with the same browser session cookie used by `ai.gitcode.com`.

Without this file, the statusline still renders model/context/git information, but GitCode token usage and mo-fix-agent remaining time cannot be fetched.

## Target File

Default path:

```text
~/.claude/.gitcode_session_cookie
```

Create it:

```bash
mkdir -p ~/.claude
$EDITOR ~/.claude/.gitcode_session_cookie
chmod 600 ~/.claude/.gitcode_session_cookie
```

Paste only the raw Cookie header value, for example:

```text
cookie_a=...; cookie_b=...; cookie_c=...
```

Do not include the literal `Cookie:` prefix.

## Export With Browser Extension

You can use a cookie export extension such as J2TEAM Cookies (`j2team_cookies`) to export the `ai.gitcode.com` / GitCode cookie, then paste the cookie string into:

```text
~/.claude/.gitcode_session_cookie
```

## Export From Browser DevTools

1. Log in to `https://ai.gitcode.com`.
2. Open browser DevTools.
3. Go to the Network tab.
4. Refresh the page or open an agent page.
5. Filter for `web-api.gitcode.com`.
6. Click a request such as:
   - `/widget/api/v1/token_usage`
   - `/aihub/api/v1/mo-fix-agent/detail`
7. In Request Headers, copy the value of `Cookie`.
8. Save that value to `~/.claude/.gitcode_session_cookie`.
9. Run `chmod 600 ~/.claude/.gitcode_session_cookie`.

## Validate The Cookie

Token usage:

```bash
cookie="$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' ~/.claude/.gitcode_session_cookie | tr '\n' ' ')"

curl -fsS 'https://web-api.gitcode.com/widget/api/v1/token_usage' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Referer: https://ai.gitcode.com/' \
  -H 'Origin: https://ai.gitcode.com' \
  -H "Cookie: $cookie" | jq .
```

Agent detail:

```bash
cookie="$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' ~/.claude/.gitcode_session_cookie | tr '\n' ' ')"

curl -fsS 'https://web-api.gitcode.com/aihub/api/v1/mo-fix-agent/detail' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Referer: https://ai.gitcode.com/' \
  -H 'Origin: https://ai.gitcode.com' \
  -H 'x-app-channel: gitcode-fe' \
  -H 'x-app-version: 0' \
  -H 'x-platform: web' \
  -H "Cookie: $cookie" | jq .
```

Useful fields in a successful agent response:

```text
remaining_seconds
expected_duration_seconds
expire_time
can_renewal
```

## Troubleshooting

`gitcode cookie missing`

The cookie file does not exist at `~/.claude/.gitcode_session_cookie`, or `GITCODE_COOKIE_FILE` points to the wrong path.

`curl: (22) 401` or an HTML login page

The cookie is expired or copied from the wrong GitCode account. Log in again and export a fresh Cookie header.

No agent line

The token API may work while the agent detail API has no active mo-fix-agent session. Start/open the GitCode agent page, then validate the detail endpoint again.
