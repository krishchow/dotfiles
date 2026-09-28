---
name: add-ssh
description: Add, update, or remove an ssh host in the private shared ssh config (secrets/ssh/config), which make install wires into ~/.ssh/config. Use when the user pastes anything ssh-shaped — an `ssh` command line, `user@host:port`, an `ssh://` URL, a `Host` block, or plain prose like "add sevenoaks at 192.168.100.254 port 3422" — or says "add an ssh host", "ssh alias for X", "change the port for X", "jump through Y", "forward port N on X", or "remove host X".
---

# add-ssh

Turn an ssh-shaped request into an edit of **one file**: `secrets/ssh/config` (inside the private `secrets` submodule). `scripts/installers/14-ssh-include.sh` has already put `Include $DOTFILES/secrets/ssh/config` at the top of `~/.ssh/config`, so there's nothing else to wire up.

## Where things go

| Thing | Location |
|---|---|
| `Host` blocks: aliases, IPs, hostnames, users, ports, forwards, jump hosts | `secrets/ssh/config`. This is the **only** file you edit. |
| `IdentityFile` | A **path** in the Host block (`~/.ssh/<key>`). The key file stays in `~/.ssh`, is never copied into either repo, and is never read. |
| Anything ssh-related in the public repo (`ssh/`, CLAUDE.md examples with real values, installers) | **Never.** This repo is public. Use placeholders like `<alias>` in docs. |
| `~/.ssh/config` | Don't edit it. Mention a conflicting local block if you find one (see Checks). |
| Passwords | Not supported: ssh_config can't store them. Suggest key auth (`ssh-copy-id -i ~/.ssh/<key>.pub <alias>`) instead. |

## Preconditions (check first, fix or stop)

1. The submodule is present: `[[ -e secrets/.git ]]`. If it isn't, run `git submodule update --init secrets`. If that fails (no access), stop and tell the user.
2. The Include is wired in: `grep -qF '# >>> dotfiles ssh >>>' ~/.ssh/config`. If it isn't, run the installer: `DOTFILES=$PWD bash -c 'source scripts/installers/14-ssh-include.sh && install'`.
3. `secrets/ssh/config` exists. If it doesn't, create it with this header:
   ```
   # Private ssh hosts — Included from ~/.ssh/config via the shell repo's
   # scripts/installers/14-ssh-include.sh.
   ```

## Parsing the request

Pull out these fields. Anything not given is **omitted** (ssh defaults apply), never guessed.

| Input shape | Fields |
|---|---|
| `ssh -p 3422 -i ~/.ssh/k krish@1.2.3.4` | `User krish`, `HostName 1.2.3.4`, `Port 3422`, `IdentityFile ~/.ssh/k` |
| `ssh -J bastion krish@10.0.0.5` | `ProxyJump bastion` (+ the rest) |
| `ssh -L 8080:localhost:80 host` | `LocalForward 8080 localhost:80` (note: space, not colon, after the local port) |
| `ssh -R 9000:localhost:3000 host` | `RemoteForward 9000 localhost:3000` |
| `ssh -D 1080 host` | `DynamicForward 1080` |
| `ssh -A host` | `ForwardAgent yes` |
| `ssh -o Key=Value …` | `Key Value` directly |
| `krish@host:3422`, `ssh://krish@host:3422` | `User`, `HostName`, `Port` |
| `[fe80::1]:2222` | `HostName fe80::1` (no brackets), `Port 2222` |
| A pasted `Host …` block | Use it as-is, normalizing the indentation to 4 spaces |
| Prose ("sevenoaks, 192.168.100.254, port 3422, user krish") | Map each phrase to its directive |

**Alias (`Host`)**, in order of preference:
1. The name the user gave ("add **sevenoaks**").
2. For a DNS hostname with no alias given, the first label (`build01.corp.example.com` → `build01`). Say which alias you picked.
3. For a bare IP with no name given, **ask**. Don't invent an alias from an IP.

Multiple space-separated patterns are fine (`Host sevenoaks so`). Wildcards (`Host *.corp`) are allowed only if the user asks for them.

**Supported directives:** any valid `ssh_config(5)` keyword works, because `ssh -G` validates it. The ones to expect are `HostName`, `User`, `Port`, `IdentityFile`, `IdentitiesOnly`, `ProxyJump`, `LocalForward`, `RemoteForward`, `DynamicForward`, `ForwardAgent`, `ServerAliveInterval`, `ServerAliveCountMax`, `AddKeysToAgent`, `UseKeychain` (macOS), `IdentityAgent`, `RequestTTY`, `RemoteCommand` and `SetEnv`. Add `StrictHostKeyChecking no` / `UserKnownHostsFile /dev/null` only if the user explicitly asks, and say that it disables host-key protection.

**Not supported. Refuse, or ask how to proceed:**
- A password, passphrase or private-key contents. Don't write these anywhere.
- `Include` lines inside `secrets/ssh/config`. The installer owns the Include wiring.

## Editing the file

- **New alias:** append the block at the end of the file, **before** any trailing `Host *` / `Match all` block. Leave exactly one blank line between blocks.
- **Existing alias** (search every pattern on each `Host` line): edit that block in place. Change only the directives requested, and never create a duplicate. The first matching block wins, so a duplicate further down would be silently ignored.
- **Remove:** delete the whole block and the blank line after it.
- **Defaults for every host** (`Host *`): keep them in a single block at the **end** of the file. Because this file is Included at the top of `~/.ssh/config`, these defaults take precedence over the local `Host *` for each directive they set. Say so.
- Format: `Host` flush left, directives indented 4 spaces, one directive per line, `Key Value` separated by a single space. Keep the header comment. A short `# comment` above a block is fine if the user gave context ("home NAS").

## Checks (after editing)

1. **Syntax and resolution:** `ssh -G <alias> 2>&1 | grep -E '^(hostname|user|port|identityfile|proxyjump) '`. A non-zero exit or a `Bad configuration option` error means the edit is wrong. Fix it before continuing. Confirm the resolved values match the request.
2. **Local conflicts:** `grep -nE '^\s*Host\s.*\b<alias>\b' ~/.ssh/config ~/.orbstack/ssh/config 2>/dev/null`. If the alias is also defined locally, ours wins for any directive both blocks set, and the local block still fills in the rest. Tell the user and suggest deleting the local block.
3. **Key path:** if you set `IdentityFile`, check that the file exists (`[[ -f <path> ]]`, without reading it). If it's missing, warn the user and offer `ssh-keygen -t ed25519 -f <path>`. Don't run it unasked.
4. Don't actually connect unless the user asks. A connection has side effects (a host-key prompt, `known_hosts` writes, possibly a hang on an unreachable IP).

## Committing

Show the resulting block or diff (`git -C secrets diff ssh/config`), then offer these steps, running them only when the user asks:

1. `git -C secrets add ssh/config && git -C secrets commit -m "ssh: add <alias>" && git -C secrets push` (use `update` / `remove` in the message as appropriate).
2. Update the pointer in the public repo: `git add secrets && git commit -m "bump secrets (ssh: <alias>)"`.

Always commit `secrets` first. If you bump the pointer before pushing `secrets`, the public repo points at a commit other machines can't fetch. Stage only `ssh/config` inside `secrets`; other files there (such as `.env`) may have unrelated uncommitted changes.

Other machines pick the change up with `git pull && git submodule update secrets`. There's nothing to reload, because ssh re-reads the Include on every run.

## Example

Request: `ssh -p 2201 -J sevenoaks pi@10.0.0.42`, "call it garage-pi".

```
Host garage-pi
    HostName 10.0.0.42
    User pi
    Port 2201
    ProxyJump sevenoaks
```

Append this at the end of `secrets/ssh/config`, run `ssh -G garage-pi` to confirm `hostname 10.0.0.42`, `user pi`, `port 2201` and `proxyjump sevenoaks`, then show the diff and offer to commit.
