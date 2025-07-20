# dtool Suite (Template Repository)

![dtool logo](logo.png)

`dtool` is a **Dev/DevOps automation suite** for **continuous delivery (CD)** and **continuous integration (CI)** across local, remote, and cloud environments (AWS, Google Cloud, etc.).  
It contains two primary tools:

- **`devtool`** – Developer automation: job tracking, reviews, SSL/CA management, VM requests, and daily workflows.
- **`dotool`** – DevOps automation: subsystem linking, VM orchestration, CI builds, deployments, and environment management.

This repository is marked as a **template** so teams can quickly bootstrap new projects with a working `dtool` setup.

---

## How to Use This Repository

### Option 1 – Start a New Project (Recommended)
Use the **template feature**:
1. Click **"Use this template"** at the top of the GitHub repository page.
2. Choose a name and owner for your new repository.
3. (Optional) Choose **Include all branches** to copy the entire commit history, or leave it unchecked for a clean history.
4. Clone your new repository and start working.

This method creates an **independent project** — not linked to `dtool`, so you can customize freely.

---

### Option 2 – Fork for Contributions
If you intend to **contribute changes back to the original `dtool`**:
1. Click **"Fork"** on the repository page.
2. Clone your fork:
   ```bash
   git clone git@github.com:<your-user>/dtool.git
   ```
3. Add the upstream reference:
   ```bash
   git remote add upstream git@github.com:mm-s/dtool.git
   git fetch upstream
   ```
4. Use pull requests to submit changes.

This keeps your fork linked to the upstream repo so you can sync and contribute.

---

## devtool v2 – Developer Automation

### Overview
`devtool` automates developer workflows, job tracking, and code reviews.  
Configuration and secrets are located under `/config`.

### Usage
```bash
bin/devtool [options] <command>
```

### Options
- `--dev_handle <XX>` – Use a specific developer handle.

### Common Hints
- `source lib/devenv` – Load bash aliases (`dt`).
- `dt jobs` – List your taken jobs.
- `dt sign_in` – Start working.

### Commands (Highlights)
- **Setup:** `deps`, `set_dev`, `forget`
- **Jobs:** `fetch`, `all`, `jobs`, `take`, `release`
- **Workflow:** `sign_in`, `sign_out`, `review`, `rr`, `sync`
- **Certificates:** `create_CA_cert`, `create_SSL_cert`, `split_CA_cert`, `view_cert`
- **VMs (Experimental):** `request_vm`, `release_vm`

Business state indicator: `🔴` (idle/offline).

---

## dotool – DevOps & Deployment Tool

### Overview
`dotool` automates subsystem linking, VM orchestration, CI builds, and deployments.  
Optimized for **Script-TV DevOps pipelines** on Linux.

### Usage
```bash
bin/dotool [options] <command>
```

### Options
- `--cfg_ss <file>` / `--cfg_hosts <file>` – Subsystem and host configs.
- `--debug` / `--release` – Build modes.
- `--batch`, `--save`, `--verbose`, `--verbose_build` – Workflow flags.

### Commands (Highlights)
- **Subsystem Linking:** `link`, `link_ss`, `link_hosts`, `unlink`, `reconfigure`
- **CI / VM:** `remote`, `vm_deploy`, `ssh node`, `ssh testnet`
- **Cache:** `cache`, `clear_cache`
- **Info:** `ss_available`, `ss_linked`, `build_deps`, `runtime_deps`, `lint_check`, `dep_graph`
- **VM Pool:** `info_vm`, `leases`, `ssh`, `report_issue`, `watch_issue`, `cleanup`

---

## Quick Start

1. Clone your project (created via template or fork):
   ```bash
   git clone git@github.com:<your-org>/<your-repo>.git
   cd <your-repo>
   ```

2. Configure subsystems and hosts:
   ```bash
   bin/dotool link
   ```

3. Build and deploy:
   ```bash
   make
   make deploy
   make deploy_dryrun  # Test deployment without changes
   ```

4. Request a VM (if needed):
   - Use `bin/devtool request_vm` (experimental) or request in the HoT Slack channel.

---

## License

MIT License © 2025 Your Organization.
