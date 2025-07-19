# dtool Suite

![dtool logo](logo.png)

`dtool` is a **Dev/DevOps automation suite** for **continuous delivery (CD)** and **continuous integration (CI)** across local, remote, and cloud environments (AWS, Google Cloud, etc.).  
It is composed of two main tools:

- **`devtool`** – Developer automation: job management, code review, SSL/CA handling, VM requests, and workflow utilities.
- **`dotool`** – DevOps/Release automation: subsystem linking, VM orchestration, CI builds, deployments, and environment management.

The suite supports:
- **Team Leads** – Review and merge management.  
- **Developers** – Showcase builds and job tracking.  
- **Release Managers** – Stage and production deployments (mono-VM and multi-VM).

---

## devtool v2 – Developer Automation

### Overview
`devtool` provides automation for developer workflows, job tracking, and review tasks.  
Configuration and secrets are located under `/config`.

### Usage
```bash
bin/devtool [options] <command>
```

### Options
- `--dev_handle <XX>` – Use a specific developer handle.

### Common Hints
- `source lib/devenv` – Load handy bash aliases (`dt`).
- `dt jobs` – List your taken jobs.
- `dt sign_in` – Start working (daily session).

### Commands
#### Setup
- `deps` – Install required system packages.
- `set_dev [XX]` – Set the developer handle.
- `forget` – Clear the developer handle.

#### Jobs (issues, tickets, orders)
- `fetch` – Update local job list.
- `all` – List all jobs.
- `jobs` – List my current jobs.
- `take [<id>]` – Take a job (with pick list if no ID).
- `release [<id>]` – Release a job.

#### Workflow
- `sign_in` / `sign_out` – Start or end the workday.
- `review <branch>` – Review a peer’s branch.
- `rr <job>` – Create a review request for a job.
- `sync` – Sync all taken jobs.

#### Certificates
- `create_CA_cert [<domain>]` – Generate a CA cert.
- `create_p2p_CA_cert [<domain>]` – Create p2p CA certs for genesis directories.
- `create_SSL_cert <domain>` – Generate wildcard certs in `/ssl/certs`.
- `check_own_CA_cert <domain>` – Verify cert matches the private key.
- `sign_CSR [<file>]` – Sign CSR messages.
- `split_CA_cert <ca_domain>` – Split chained certs into individual files.
- `view_cert <pem>` – Decode a PEM file.

#### VM (experimental)
- `request_vm` – Launch a VM instance (not implemented yet).
- `release_vm` – Release VM resources (not implemented yet).

### State
- Business state indicator: `🔴` (idle/offline).

---

## dotool – DevOps & Deployment Tool

### Overview
`dotool` handles subsystem linking, builds, VM orchestration, CI automation, and cloud deployments.  
Designed for **Script-TV DevOps pipelines** on Linux.

### Usage
```bash
bin/dotool [options] <command>
```

### Options
- `--home <path>` – Set home directory.
- `--cfg_ss <file>` – Subsystems configuration file.
- `--cfg_hosts <file>` – Hosts definition file.
- `--debug` / `--release` – Set build mode.
- `--batch` – Non-interactive mode.
- `--save` – Persist changes.
- `--verbose` – Show confirmations.
- `--verbose_build [0|1]` – Toggle compilation details.

### Core Commands
#### Subsystem & Host Configuration
- `link` – Interactive linking of `cfg_ss.env` and `cfg_hosts.env`.
- `link_ss <dir> <net> <inst> <mnemonic>` – Link a single subsystem (and optionally its dependencies).
- `link_hosts` – Relink only hosts.
- `unlink` – Remove subsystem and host links.
- `reconfigure` – Clean and relink.

#### CI Computer
- `remote` – SSH into CI computer.
- `github` – Add SSH key to GitHub for cloning.
- `vm_deploy` – Build on CI machine and deploy to VM.

#### Node Operations
- `ssh node` – SSH into dev node.
- `ssh testnet` – SSH into testnet node.

#### Cache
- `cache` – Interactive cache management.
- `clear_cache <ss>` – Clear cache for a subsystem (or `all`).

#### Information
- `ss_available` – List available subsystems.
- `ss_linked` – List currently linked subsystems.
- `build_deps` – Show build dependencies.
- `runtime_deps` – Show runtime dependencies.
- `list_ports` – Display TCP listening ports.
- `print_conf` – Show active configuration.
- `lint_check` – Source code linting.
- `dep_graph` – Output dependency graph.
- `cables` – Print subsystem variables and dependencies.

#### VM Pool & Misc
- `info_vm [<vm>]` – Show VM details.
- `leases` – List all VM leases.
- `ssh [<vm>]` – SSH into VM (`test`, `node`, etc.).
- `report_issue` / `watch_issue <id>` – Record and monitor issues.
- `cleanup` – Fix stale sudo-related states.
- `help` – Show help text.

---

## Deployment Workflow

1. **Configure subsystems and hosts**:
   ```bash
   bin/dotool link
   ```

2. **Build and deploy**:
   ```bash
   make
   make deploy
   make deploy_dryrun  # Dry-run without writing changes
   ```

3. **Request VMs or troubleshoot**:
   - Ask for VM allocation in HoT Slack channel.
   - Use `report_issue` for support.

---

## License

MIT License © 2025 Your Organization.
