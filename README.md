# walletlink for Grok

Resolve Ethereum wallet addresses to the X and Farcaster accounts their owners
attested, and find the wallets behind a handle, directly from Grok. This plugin
connects Grok to the hosted [walletlink.social](https://walletlink.social) MCP
server and ships a skill that teaches the agent how to use it well.

walletlink.social maintains an index of millions of wallets with the social
identities their owners published onchain (ENS records, Farcaster
verifications) or in attested registries. Every identity in a result reports
whether the owner attested it or whether it was correlated by a third party.
Nothing is inferred from display names or bios.

## What the agent can do

- “Who is 0xabc…?”: resolve one address to its X handle, Farcaster account,
  ENS name, Lens profile and GitHub account, with attestation and reachability
  for each.
- Resolve a holder list in one batched call, up to the plan’s batch ceiling.
- Reverse lookups: which wallets are attested to an X handle or a Farcaster
  username, ordered by follower count.
- Check index coverage and the account’s credit balance, free.

## Components

| Path | What it is |
| --- | --- |
| `.mcp.json` | The hosted MCP server endpoint |
| `skills/walletlink/` | A skill covering tool selection, cost and result semantics |
| `.grok-plugin/plugin.json` | The plugin manifest |

## Network endpoints and credentials

Declared for review, per the marketplace security expectations:

- The plugin calls exactly one network endpoint:
  `https://walletlink.social/api/mcp` (streamable HTTP MCP). Its tools proxy
  the documented REST API at `https://walletlink.social/api/v1/*` server-side.
- The plugin ships no credentials, runs no local code, installs no hooks and
  requests no filesystem access.
- Authentication happens at the server, three ways:
  - **OAuth 2.1**: clients following the MCP authorization specification get a
    consent screen on the first tool call (PKCE, public client, dynamic client
    registration supported). Access tokens last an hour and renew.
  - **API key**: an `Authorization: Bearer wts_live_...` header, self-serve at
    [walletlink.social](https://walletlink.social) for accounts holding
    credits.
  - **x402**: agents can buy access with USDC on Base, no account needed. See
    the [agent pack](https://docs.walletlink.social/agent-pack).
- Discovery (`initialize`, `tools/list`) needs no credential and is
  rate-limited by IP at the server.

## Pricing and limits

Metering is per **match**: one credit per address that resolves to an X handle
or a Farcaster account. Misses are free, and so are addresses carrying only an
ENS name, a Lens profile or a GitHub account. The free allowance is 100 matches
per rolling 30 days. Rate limits run on three windows and are reported in tool
results and response headers. Full reference:
[docs.walletlink.social](https://docs.walletlink.social).

## Development

CI validates the manifest shapes and smoke-tests the live server (see
`.github/workflows/ci.yml`). No build step: the plugin is configuration and
prose.

## License

[MIT](LICENSE)
