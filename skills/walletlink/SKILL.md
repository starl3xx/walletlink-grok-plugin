---
name: walletlink
description: >-
  Resolve Ethereum wallet addresses to the social accounts their owners
  published (X, Farcaster, ENS, Lens, GitHub), and find the wallets attested to
  an X handle or Farcaster username. Use when a task involves identifying who
  is behind a wallet address, reaching the holders of a token or NFT
  collection, or mapping a social handle back to its addresses.
---

# walletlink

walletlink.social answers two questions about an Ethereum address: which social
accounts its owner published, and which addresses a given X handle or Farcaster
account is attested to. Balances, transfers and prices are a block explorer’s
job, not this server’s.

An identity is attested when the wallet owner published the link themselves:
a Farcaster verification, an onchain ENS record, an attested-social sign-in,
or a manually verified record. Anything else is correlated, and labelled so.
Nothing is inferred from a display name or a bio. This distinction is the
product: `attested: true` is the owner’s own claim; `attested: false` means
the record rests on correlation alone; `attested: null` means the record
carried no classified evidence, which is a different claim from “not
attested”. Evidence classes are recorded per wallet, so `attested` reflects
the record’s strongest evidence, not each identity separately.

## The tools

| Tool | What it does | Cost |
| --- | --- | --- |
| `walletlink_resolve_wallets` | One or more addresses to their identities | 1 credit per address that resolves to an X or Farcaster account; misses free |
| `walletlink_wallets_by_x_handle` | X handle to the wallets behind it | 1 credit per wallet returned, up to 100 a page |
| `walletlink_wallets_by_farcaster_username` | Farcaster username to its wallets | 1 credit per wallet returned, up to 100 a page |
| `walletlink_index_coverage` | How much of the index carries each identity type | Free |
| `walletlink_account_balance` | Credits left and rate-limit standing | Free |

“Who is 0xabc?” is one `walletlink_resolve_wallets` call with one address. A
holder list is the same call with up to 50 addresses; send them all in one
call rather than splitting, since splitting saves no credits. Pace multi-batch
runs a minute apart: a batch spends one request-unit per address of the
60-per-minute window, so a full 50-address call is nearly a whole minute. Read
the reset time from the quota block every result carries.

The reverse direction is the expensive one: a single widely held handle can
spend 100 credits in one page. Call `walletlink_account_balance` first when
that matters.

## Reading results

- A field that is absent was not resolved. Absent is not false: a missing
  `reaches_someone` means the handle was not checked, not that nobody is
  behind it.
- `found: false` with `previously_checked` set means the index looked at that
  address before and found nothing. Neither case is charged.
- `stale: true` marks a record past its freshness window; it is still served.
- An X handle can be attested by its owner and suspended today, or freed and
  since taken by a stranger. Check `reachability` before treating a handle as
  a way to reach someone.
- Farcaster usernames can carry a `.eth` suffix. Pass them whole: stripping
  the suffix finds nothing.

## Authentication

Discovery (`initialize`, `tools/list`) needs no credential. Tool calls need
one of:

- **OAuth**: clients that follow the MCP authorization specification get a
  consent screen on the first tool call. No key to manage.
- **API key**: an `Authorization: Bearer wts_live_...` header. Keys are
  self-serve at https://walletlink.social for any account holding credits.
- **x402**: an autonomous agent can buy access with USDC on Base, no account
  needed. See https://docs.walletlink.social/agent-pack.

The free allowance is 100 matches per rolling 30 days. Full reference:
https://docs.walletlink.social.
