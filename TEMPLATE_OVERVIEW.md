# Deploy and Host EmailFlare API on Railway

EmailFlare is a transactional email API with an admin dashboard. Your apps POST to one endpoint, and EmailFlare sends through the Cloudflare Email Sending API using your own Cloudflare account. The dashboard covers sending domains, reusable templates, scoped API keys, send logs, suppressions, mailing lists with one-click unsubscribe, and a Test Mailbox.

## About Hosting EmailFlare API

This template runs EmailFlare's API product in one container on a single volume. Caddy serves the dashboard and proxies the API, the Node.js server handles sending, and an embedded SQLite database (mesahub) keeps your domains, keys, templates and logs on the `/data` volume.

The image is built from EmailFlare's current code (trunk commit `cf31f33`, November 2026) and pinned to that build, so a redeploy never pulls a surprise upgrade.

There are no required inputs. The admin password and session secret are generated for you. Cloudflare credentials are optional at deploy time: without them you can already create test API keys and send with them, and those messages land in the Test Mailbox instead of being delivered. Add your Cloudflare token whenever you are ready to send for real.

## Common Use Cases

- Password resets, sign-in codes, receipts and notifications for your own apps through one HTTP API
- Giving each app or environment its own scoped API key, limited to the domains it may send from
- Keeping sent-mail logs, bounces and suppressions on infrastructure you control
- Testing email flows in staging with test keys that never deliver

## Dependencies for EmailFlare API Hosting

- A Railway volume at `/data` for the embedded SQLite database
- A Cloudflare account with Email Sending enabled on a domain you own, for live delivery (optional at deploy time)

### Deployment Dependencies

- [EmailFlare repository](https://github.com/0xdps/emailflare)
- [EmailFlare self-hosting guide](https://github.com/0xdps/emailflare/blob/trunk/docs/SELF_HOSTING.md)
- [Cloudflare API token guide](https://emailflare.dev/cloudflare-token)
- [Template source and image build](https://github.com/hmseeb/emailflare-railway-template)

### Implementation Details

**First login**

1. Open the EmailFlare service in Railway, go to **Variables**, and copy `ADMIN_TOKEN`.
2. Open the service's public URL and paste the token on the login screen.

**Try it without Cloudflare**

1. In the dashboard, go to **Keys** and create a key of type **test** with global scope. Copy it; it is shown once.
2. Send a message:

```bash
curl -X POST https://<your-domain>/v1/send \
  -H "Authorization: Bearer eftest_..." \
  -H "Content-Type: application/json" \
  -d '{"from":"hello@example.com","to":"you@example.com","subject":"Hi","text":"It works"}'
```

3. Open **Test Mailbox** in the dashboard to read it. Test keys never deliver mail.

**Going live**

1. Create a Cloudflare API token with **Account > Email Sending (Edit)** and **Zone > Email Routing (Edit)**, see the token guide above.
2. Set `CF_API_TOKEN` and `CF_ACCOUNT_ID` on the service. Railway redeploys it.
3. In the dashboard, add your sending domain under **Domains** and follow the DNS steps it shows.
4. Create a **live** key scoped to that domain and send with it.

**Variables**

| Variable | Default | Purpose |
| --- | --- | --- |
| `ADMIN_TOKEN` | generated, 48 chars | Dashboard password and admin API token |
| `SESSION_SECRET` | generated, 64 chars | Signs session cookies |
| `CF_API_TOKEN` | empty | Cloudflare token for live sends |
| `CF_ACCOUNT_ID` | empty | Cloudflare account ID for live sends |
| `MESAHUB_URL` | `mh://local/emailflare` | Embedded SQLite on the volume |
| `PORT` | `8080` | Port the container serves on |

To rotate the admin password, change `ADMIN_TOKEN` (32 characters minimum) and redeploy.

**Good to know**

- All sending goes through Cloudflare's API with your token. The container never opens an SMTP connection, and Cloudflare's own sending rules and limits apply.
- This template does not include EmailFlare's Inbox product or its Cloudflare Workers (bounce forwarding, inbound mail). Those deploy on Cloudflare, not Railway.
- Single instance with local SQLite. Do not scale the service to more than one replica; back up the `/data` volume if your logs matter.

**Troubleshooting**

- *"Invalid token" at login*: paste `ADMIN_TOKEN` exactly, with no trailing space.
- *Live key returns "API key not authorized for this domain"*: the `from` address must use a domain added under Domains and allowed on that key.
- *Live sends fail with a Cloudflare error*: check the token scopes and that `CF_ACCOUNT_ID` belongs to the same account.

## Why Deploy EmailFlare API on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying EmailFlare API on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
