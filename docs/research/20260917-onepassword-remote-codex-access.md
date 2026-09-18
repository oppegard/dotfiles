# 1Password access when Codex is controlled remotely

Researched 2026-09-17 from current first-party OpenAI and 1Password
documentation. No vaults, items, credentials, or secret values were accessed.

## Conclusion

There is no documented, supported way for ChatGPT on an iPhone to approve a
1Password authorization request raised on a Mac.

These are two separate approval boundaries:

- **Codex Remote approval:** OpenAI documents that ChatGPT on iOS can send
  prompts, answer questions, and approve Codex commands or actions. The command
  still runs on the connected Mac or SSH environment, using that host's files,
  credentials, permissions, and security controls. [OpenAI: Remote
  connections](https://learn.chatgpt.com/docs/remote)
- **1Password approval:** 1Password CLI desktop integration uses local IPC and
  asks for explicit authorization through the Mac's OS prompt, using Touch ID,
  Apple Watch, or the Mac device password. This authorization is independent of
  Codex's action approval. [1Password: CLI app
  integration](https://www.1password.dev/cli/app-integration) and [app
  integration security](https://www.1password.dev/cli/app-integration-security)

The documentation does not explicitly say that iPhone approval is impossible;
it positively documents only local desktop approval and provides no mobile
relay. Therefore the safe conclusion is **unsupported/not documented**, not a
claim that no workaround could ever exist.

## Local Mac behavior

### Desktop app plus CLI

This is the strongest fit for interactive local development. Each new terminal
window or tab requires local authorization. On macOS, authorization is scoped
to that terminal session and its subprocesses, expires after 10 minutes of
inactivity, has a 12-hour hard limit, and is revoked when 1Password locks.
[1Password: app integration security](https://www.1password.dev/cli/app-integration-security)

Pre-authorizing a normal Terminal window does not establish that a separately
started Codex shell will inherit authorization; the documented boundary is the
terminal session. A remote Codex request can trigger the `op` command, but a
fresh 1Password prompt still needs approval at the Mac.

Manual `op signin` is a weaker fallback. Its session expires after 30 minutes
of inactivity, and 1Password warns that another process running as the same OS
user may be able to access the account. 1Password explicitly recommends desktop
integration for non-interactive local shells and a service account or Connect
server for non-interactive remote shells. [1Password: manual CLI
sign-in](https://www.1password.dev/cli/sign-in-manually)

### `.env` choices

- A 1Password Environment can be mounted as a local `.env` path on Mac or
  Linux. It is a named pipe rather than a plaintext file on disk. The first read
  prompts in the desktop app; after approval, every local process can read it
  until 1Password locks. There is no per-process distinction, concurrent reads
  can fail, and aggressive file watchers can misbehave. [1Password: local
  `.env` files](https://www.1password.dev/environments/local-env-file)
- `op run` supplies variables only to the child process for its lifetime. This
  avoids a persistent resolved `.env`, although 1Password warns that processes
  running as the same user may be able to inspect one another's environments.
  [1Password: load secrets into the
  environment](https://www.1password.dev/cli/secrets-environment-variables)
- When a tool truly requires a regular file, `op inject` can resolve a checked-in
  template to a plaintext output file. 1Password says to delete that resolved
  file when it is no longer needed. [1Password: load secrets into config
  files](https://www.1password.dev/cli/secrets-config-files)

The 1Password Environments MCP server does not bypass this boundary. It runs
locally in the desktop app over `stdio`, shows local authorization prompts, does
not return secret values to the agent, and does not support remote-only MCP
clients. It can help Codex create and manage a local Environment mount, but it
is not a phone-to-Mac secret-approval channel. [1Password: Environments MCP
server](https://www.1password.dev/environments/mcp-server)

## Disposable or headless remote VM

OpenAI's SSH support makes the topology explicit: the ChatGPT desktop app uses
SSH to start Codex on the remote host; remote project chats use the remote
filesystem and shell, while the phone still controls the connected desktop
host. The remote host therefore needs its own workable secret-authentication
path. [OpenAI: Remote connections](https://learn.chatgpt.com/docs/remote)

### Preferred default: service account

For one disposable VM, the simplest supported 1Password-native design is:

1. Put only the required values in a dedicated vault or 1Password Environment.
2. Create a read-only service account scoped only to that resource, with an
   expiry where practical.
3. Provision its bearer token to the VM through the VM/provisioning system,
   never through source control, an image, or the agent prompt.
4. Use the token with 1Password CLI (`op run`, `op inject`, or `op environment
   read`) or an SDK, then revoke or discard it with the VM.

Service accounts require no human interaction and work with CLI and SDKs. They
cannot access built-in Personal, Private, Employee, or default Shared vaults;
Environment access is read-only; access and permissions are immutable after
creation; and requests are rate-limited. The token remains the **secret-zero**
problem and must be protected like a password. [1Password: service account
setup](https://www.1password.dev/service-accounts/get-started) and [programmatic
Environment access](https://www.1password.dev/environments/read-environment-variables)

### Connect server

Connect is a self-hosted private REST API backed by API and sync containers. It
requires a sensitive credentials file plus client access tokens, caches data in
your infrastructure, and can serve repeated reads without repeatedly fetching
from 1Password. It is attractive for many or long-lived workloads that need a
durable private service, but adds deployment, availability, networking, token,
and patching responsibilities. It is usually too much machinery for one
short-lived sandbox, and the client token remains secret zero. [1Password:
Connect overview](https://www.1password.dev/connect) and [Connect
setup](https://www.1password.dev/connect/get-started)

### SDKs

The Go, JavaScript, and Python SDKs can authenticate through the local desktop
app or a service account. They are useful when an application needs typed
access, error handling, or a narrow controller that resolves only approved
secret references. They are unnecessary overhead when a shell wrapper around
`op run` or `op inject` is sufficient. The SDKs are currently version 0, so
minor-version upgrades may contain breaking changes. [1Password:
SDKs](https://www.1password.dev/sdks)

### SSH agent and agent forwarding

The 1Password SSH agent solves a different problem: it lets SSH and Git clients
use keys without reading the private key. Agent forwarding can let a trusted VM
request SSH/Git signatures from the Mac while the key stays in the local
1Password process. It does **not** supply arbitrary vault fields or render a
`.env` file.

Fresh key use can still require local Mac approval. Once a key is approved for
a forwarded session, any process running as the same remote OS user can use that
key for the session. 1Password recommends forwarding only to trusted hosts and
scoping `ForwardAgent` to a command or specific host, never all hosts.
[1Password: SSH agent forwarding](https://www.1password.dev/ssh/agent/forwarding)

## Practical recommendation

- **At the Mac:** use desktop authorization with `op run`; use a mounted
  1Password Environment only when software requires a `.env` path. Treat
  phone-controlled operation as usable only while the needed Mac-side
  authorization remains valid, not as a way to approve 1Password remotely.
- **For a clean VM controlled from the phone:** use a dedicated, least-privilege,
  preferably expiring service account. Inject its token through the provisioning
  boundary, use process-scoped variables when possible, and destroy or revoke
  the credential with the VM.
- **For shared durable infrastructure:** evaluate Connect when its private API,
  caching, and centralized audit boundary justify the operational cost.
- **For Git/SSH on the VM:** optionally use host-scoped SSH-agent forwarding,
  but pair it with a separate service-account or Connect path for application
  secrets.

If phone-side human approval for every secret read is a hard requirement, the
current OpenAI and 1Password documentation does not establish a supported
architecture for it. That requirement would need a different broker or secret
manager with an explicit cross-device approval protocol.

## Source and uncertainty notes

- Only current first-party OpenAI and 1Password documentation was used.
- Product availability can vary by rollout: OpenAI says Remote availability may
  vary, and workspace admins may need to enable it.
- 1Password Environments CLI commands such as `op environment read` and
  `op run --environment` are currently documented as requiring a beta CLI
  (`2.33.0-beta.02` or newer). The non-Environment secret-reference forms of
  `op run` and `op inject` are distinct.
- No live test was performed, so the exact process/TTY identity used by the
  ChatGPT desktop app was not verified.
