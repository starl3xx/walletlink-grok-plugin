---
name: walletlink
description: >-
  Resolve Ethereum wallet addresses to the social accounts their owners
  published (X, Farcaster, ENS, Lens, GitHub), and find the wallets attested to
  an X handle or Farcaster username. Use when a task involves identifying who
  is behind a wallet address, reaching the holders of a token or NFT
  collection, or mapping a social handle back to its addresses.
homepage: https://walletlink.social
---

# walletlink

walletlink.social answers two questions about an Ethereum address: which social
accounts its owner published, and which addresses a given X handle or Farcaster
account is attested to. Balances, transfers and prices are a block explorer’s
job, not this server’s.

An identity is attested when the wallet owner published the link themselves: a Farcaster verification, an onchain ENS record, an attested-social sign-in, or a manually verified record. Anything else is correlated, and labeled so. Nothing is inferred from a display name or a bio. This
distinction is the product: `attested: true` is the owner’s own claim,
`attested: false` means the record rests on correlation alone, and
`attested: null` means the record carried no classified evidence, which is a
different claim from "not attested".

The index holds over 4.8 million wallets across eight chains.

## Connecting

The server speaks MCP over HTTP at `https://walletlink.social/api/mcp`.

Discovery (`initialize`, `tools/list`) needs no credential. Tool calls need
one of:

- **OAuth**: clients that follow the MCP authorization specification get a
  consent screen on the first tool call. No key to manage.
- **API key**: an `Authorization: Bearer wts_live_<key>` header. Keys are
  self-serve at https://walletlink.social for any signed-in account, free allowance included.
  **Use this if you are running inside a chat host.** Some cannot open a
  consent screen at all (X and Grok report `no_auth_link`), so OAuth can
  never complete there however many times it is retried. The symptom is
  specific and worth recognizing: every tool is listed, because discovery
  needs no credential, and then every call reports that a sign-in is still
  needed no matter how often the user authorizes. That is a host that cannot
  start a sign-in, not a sign-in that failed. Ask the user for a key instead
  of retrying the connection.
- **x402**: an autonomous agent can buy access with USDC on Base, no account
  needed. That key resolves addresses; the two reverse lookups need an account
  and answer it with 403 ACCOUNT_REQUIRED. See
  https://docs.walletlink.social/agent-pack.

## The tools

| Tool | What it does | Cost |
| --- | --- | --- |
| `walletlink_resolve_wallets` | One or more addresses to their identities | 1 credit per address that resolves to an X or Farcaster account; misses free |
| `walletlink_wallets_by_x_handle` | X handle to the wallets behind it | 1 credit per wallet returned, up to 100 a page |
| `walletlink_wallets_by_farcaster_username` | Farcaster username to its wallets | 1 credit per wallet returned, up to 100 a page |
| `walletlink_index_coverage` | How much of the index carries each identity type | Free |
| `walletlink_account_balance` | Credits left and rate-limit standing | Free |
| `walletlink_submit_job` | A deep scan of a large list: live resolution on wallets the index has not checked | Billed as matches when the job completes, same price as resolving |
| `walletlink_job_status` | Progress and paged results for a submitted job | Free |
| `walletlink_estimate_list` | A quote before the spend: how many of a list are in the index and what a resolve would bill | Free; minimum ten distinct wallets; counts only |

"Who is 0xabc?" is one `walletlink_resolve_wallets` call with one address. A
holder list is the same call with up to 50 addresses; send them all in one call
rather than splitting, since splitting saves no credits. A batch spends one
request-unit per address of the per-minute window, so pace multi-batch runs a
minute apart and read the reset time from the quota block every result carries.

The reverse direction is the expensive one: a single widely held handle can
spend 100 credits in one page. Call `walletlink_account_balance` first when
that matters, or `walletlink_estimate_list` for a free count before anything
is billed.

For a list above 50 addresses, or when never-checked wallets deserve a live
resolution, submit a job instead. It runs the full pipeline in the background
and bills matches only at completion; a failed job is never billed. One job may
be active per account, and completed results arrive one 100-row page per call
until `next_offset` is null.

## What it costs

A match is a wallet resolved to an X handle or a Farcaster account. Wallets that resolve to nothing, and wallets carrying only an ENS name, a Lens profile or a GitHub account, are never billed.

The free allowance is 100 matches per rolling 30 days. Beyond that, credits are bought once and last 12 months; the entry pack is 250 matches for $29. There are no subscriptions.

## Reading results

- A field that is absent was not measured. Absent is not false: a missing reachability means the handle was not checked, never that nobody is behind it.
- `found: false` with `previously_checked` set means the index looked at
  that address before and found nothing. Neither case is charged.
- `stale: true` marks a record past its freshness window; it is still served.
- A checked X handle carries one of four states: live, suspended, unclaimed, or reassigned. A handle can be attested by its owner and suspended today, so a handle is not a promise that anyone is behind it.
- Farcaster usernames can carry a `.eth` suffix. Pass them whole: stripping
  the suffix finds nothing.

## What to expect from a list

The chain decides the match rate more than the collection does. Measured on 2026-08-17: 46.2% of 35,294 Base holders were reachable on X or Farcaster, against 16.6% of 17,462 on Ethereum. A list from a low-attestation community can legitimately come back nearly empty, and that is an answer about the list rather than a failure.

Full reference: https://docs.walletlink.social
