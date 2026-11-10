# Security

Report suspected vulnerabilities through this repository's GitHub private vulnerability reporting feature. Do not include real authentication URLs, codes, cookies or credentials in public issues.

The app approves requests supplied through its command line or authentication input. Keep that input local and trusted. It does not verify which process originally obtained a pasted URL. Only the initial AWS host and path receive automation. Identity-provider pages receive only a read-only check for visible manual controls; the helper does not read credential values or click those controls. A window is created only when manual interaction remains necessary, or when explicitly requested with `--visible`. Confirmation pages require a matching supplied code or manual input.

WebKit stores a separate persistent sign-in session. Protect your macOS account and disk. The app does not collect AWS credentials, export cookies or write authentication URLs to its logs. It does not bypass MFA or organisation session policy.
