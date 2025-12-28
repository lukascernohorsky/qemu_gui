# Security Model (baseline)

- Privileged operations must be explicit; future drivers will honor pkexec/doas/sudo preferences and show command previews.
- SSH transport (planned) will respect host key checking and user-supplied identity files; no automatic bypass of host verification.
- Dry-run mode surfaces argv without execution for auditability.
- Logs avoid secret material; diagnostics will redact sensitive fields before bundling.
- Download verification (planned) will require checksum verification for catalog-sourced media and prefer signatures when provided.
