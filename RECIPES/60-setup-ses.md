# Set up Amazon SES for magic-link email

SES is the declared email provider (see `STACK.md`). Any Swoosh-compatible
SMTP provider will work with the existing config — this recipe covers the
SES-specific setup steps.

## 1. Create an SES identity (one-time, per domain)

In the AWS console, region = the one closest to your VPS:

- **Domain identity** — add your sending domain (e.g. `send.example.com`
  or the apex `example.com`)
- AWS prints 3 CNAMEs for DKIM — add them to Cloudflare DNS
- For better deliverability, also add:
  - **SPF**: `v=spf1 include:amazonses.com -all` as TXT on the sending domain
  - **DMARC**: `v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com` at `_dmarc.example.com`
- Wait for DKIM status to go green (usually <30 min once DNS propagates)

## 2. Move out of the sandbox

By default SES can only send to verified addresses. Request production
access from the SES console → Account dashboard → "Request production
access." Include:

- Use case: transactional (magic-link login, receipts)
- Expected volume per day
- How you handle bounces/complaints (we do; SES delivers notifications
  to SNS — wire later)

Approval usually takes <24 h.

## 3. Generate SMTP credentials

SMTP credentials are IAM credentials with `ses:SendRawEmail` permission,
encoded for SMTP use:

1. SES console → SMTP settings → "Create SMTP credentials"
2. AWS auto-creates an IAM user and downloads a CSV with username + password
3. **Store these outside the repo.** Use your VPS's env file or a secrets
   manager. Never commit them.

## 4. Set env vars on the VPS

```bash
# /etc/saas_starter/env (readable by the systemd unit only)
SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=<from step 3>
SMTP_PASSWORD=<from step 3>
FROM_EMAIL=no-reply@send.example.com
```

The `relay` value depends on your SES region (us-east-1, eu-west-1, etc.).

## 5. Verify it works

```bash
# On the VPS
systemctl restart saas_starter
# Trigger a magic link
curl -X POST https://your-host/users/log-in -d 'user[email]=you@your-domain.com'
# Check CloudWatch Logs → the SES delivery event, or check your inbox
```

## 6. Monitor bounces + complaints

SES publishes bounce/complaint events to an SNS topic. Two options:

- **Quick**: configure SNS to email you on bounce/complaint
- **Clean**: SNS → HTTPS webhook → a Phoenix controller that updates
  `users.email_status` and stops sending to repeat bouncers

Second option is a Stage-2 recipe (not yet written).

## Common pitfalls

- Using port **25** — blocked on most VPS providers. Always 587 or 465.
- Forgetting the DKIM CNAMEs — mail goes to spam.
- Not moving out of the sandbox — recipients who aren't verified get no email.
- Using an **apex domain** SPF without `include:amazonses.com` — SES
  cannot authenticate, messages tagged as spam.
- SMTP creds look like IAM keys but **they are not** — don't try to use
  `AKIA...` / secret pairs in SMTP fields. Use the credentials the SES
  "Create SMTP credentials" flow returns.
