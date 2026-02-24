# Permissions & Authorization
> Chrome Extension permissions, chrome.identity, per-site authorization

## Manifest Permissions

Declare only permissions actually used — extra permissions hurt store approval:

```json
{
  "permissions": ["storage", "activeTab", "tabs"],
  "host_permissions": ["https://*.example.com/*"],
  "optional_permissions": ["history", "bookmarks"]
}
```

| Permission | Use when |
|-----------|---------|
| `storage` | Using `chrome.storage` |
| `activeTab` | Accessing current tab on user action |
| `tabs` | Accessing tab URLs/titles without user action |
| `scripting` | Programmatic content script injection |
| `identity` | OAuth via `chrome.identity` |

## Optional Permissions

Request at runtime — better UX than requiring all on install:

```typescript
const granted = await chrome.permissions.request({
  permissions: ['history'],
  origins: ['https://*.example.com/*']
})
```

## OAuth / User Identity (`chrome.identity`)

For Google OAuth or other OIDC flows:

```typescript
const token = await chrome.identity.getAuthToken({ interactive: true })
// Use token for API calls
```

- Only works in Chrome (not Firefox WebExtensions)
- Add OAuth client ID to manifest: `"oauth2": { "client_id": "...", "scopes": [...] }`

## Content Script Permissions

- Content scripts run in the context of web pages
- `activeTab` covers current tab when extension icon is clicked
- For proactive injection across tabs: add `host_permissions`

## Authorization in Extension UI

- No server-side session — store auth tokens in `chrome.storage.local` (never `sync`)
- Encrypt sensitive tokens if stored locally
- Check token validity on popup open — refresh or prompt re-auth if expired

## Security Rules

- NEVER store passwords in plaintext
- Content Security Policy (CSP) is enforced by MV3 — no `eval()`, no inline scripts
- Validate all messages from content scripts (untrusted source)

```typescript
// background: validate message sender
chrome.runtime.onMessage.addListener((msg, sender) => {
  if (!sender.tab) return  // Only accept messages from content scripts
  // additional origin checks if needed
})
```
