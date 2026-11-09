---
name: sradownloader-setup
description: Install, configure, and verify sradownloader (v3.11-mod fork) and its prerequisites: Python 3, SRA Toolkit fasterq-dump, gzip, and optional axel. Use when setting up sradownloader on a new machine, when a download fails because a required tool is missing, or when checking whether the environment is ready to download.
---

# sradownloader-setup — install and verify

This skill configures the environment for `sradownloader` (repo root,
`VERSION = "3.11-mod"`, single-file Python script). For how to download
data once set up, use the `sradownloader` skill.

## What is needed

| Tool | Required? | What it is for | If missing |
| --- | --- | --- | --- |
| `python3` (>= 3.6) | Yes | Runs `sradownloader` (standard library only) | Nothing works |
| `sradownloader` itself | Yes | The download script | Clone the repo (below) |
| `gzip` | For NCBI only | Compresses FASTQ files after `fasterq-dump` | NCBI path is disabled with a warning; ENA still works |
| `fasterq-dump` (SRA Toolkit) | For NCBI only | Downloads from NCBI as fallback when ENA fails | NCBI path is disabled with a warning; ENA still works |
| `axel` | No (recommended) | Multi-connection ENA downloads | Built-in FTP downloader with progress bar is used instead |

Network access is needed to EBI ENA (`www.ebi.ac.uk`, plus FTP to ENA
servers) and, for GEO sample names, to NCBI
(`www.ncbi.nlm.nih.gov/sra/`). Downloads are large — check free disk
(`df -h`) before a big run.

## Install sradownloader

```bash
git clone https://github.com/luxiangze/sradownloader.git
cd sradownloader

# The file is stored without the executable bit; fix that once,
# or always invoke it as `python3 sradownloader ...`.
chmod +x sradownloader

./sradownloader --version   # expect: SRA downloader v3.11-mod
./sradownloader --help      # full option list
```

Optional: put it on `PATH`, e.g. symlink it into `~/.local/bin`:

```bash
ln -s "$PWD/sradownloader" ~/.local/bin/sradownloader
```

Note: a non-interactive SSH shell on macOS has a minimal `PATH`
(`/usr/bin:/bin:/usr/sbin:/sbin`) that does not include `~/.local/bin`,
so a bare `sradownloader` fails there — use the full path
(`~/.local/bin/sradownloader`) or export the directory into `PATH`
first.

## Install the prerequisites

Install only what the planned download path needs. ENA-only downloads
need nothing beyond Python 3.

```bash
# macOS (Homebrew)
brew install axel            # optional, for faster ENA downloads
brew install sratoolkit      # provides fasterq-dump (NCBI fallback)

# Ubuntu / Debian
sudo apt install axel sra-toolkit   # gzip is normally preinstalled

# conda / mamba
conda install -c conda-forge axel
conda install -c bioconda sra-tools
```

After installing the SRA Toolkit, run its one-time configuration (it is
interactive the first time):

```bash
vdb-config -i
```

Without this step `fasterq-dump` may refuse to run, and
`sradownloader` will warn `Couldn't find fasterq-dump` and disable the
NCBI path.

## Verify the environment

Run the bundled check (read-only, it installs nothing):

```bash
bash scripts/check-setup.sh [path-to-sradownloader]
# no argument: looks for ./sradownloader, then `sradownloader` on PATH
```

Expected output on a complete setup:

```text
PASS  python3 ...
PASS  sradownloader ... (SRA downloader v3.11-mod)
PASS  gzip ...
PASS  fasterq-dump ... (NCBI fallback available)
INFO  axel ... (ENA downloads will use axel)
```

How to read the result:

- `FAIL` on `python3` or `sradownloader` — fix before downloading
  anything (install Python 3, or clone the repo / fix the path).
- `WARN` on `fasterq-dump` or `gzip` — ENA-only downloads still work;
  the NCBI fallback is disabled. Install the SRA Toolkit (above) if
  NCBI fallback is wanted.
- `INFO` on `axel` — not an error; the built-in FTP downloader is used.

The program itself also self-checks at startup: it prints
`Found axel — will use it for ENA downloads` (or the not-found variant),
`Found fasterq-dump at ...` / `Found gzip`, and warns on stderr when a
tool is missing. If both download sources end up disabled it exits with
`ERROR: Both NCBI and ENA download options are unavailable` (exit 1).

## Install these skills for an agent

```bash
npx skills add luxiangze/sradownloader -g -y
```

This installs `sradownloader` and `sradownloader-setup` from this repo
(`.agents/skills/` and `.claude/skills/` carry identical copies) into
the agent's global skills directory, e.g. `~/.agents/skills/`.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `./sradownloader: Permission denied` | Executable bit missing after clone | `chmod +x sradownloader`, or run `python3 sradownloader ...` |
| `sradownloader: command not found` | Not on `PATH` (e.g. minimal non-interactive SSH `PATH` on macOS) | Use the full path, or `export PATH="$HOME/.local/bin:$PATH"` |
| `WARNING: Couldn't find fasterq-dump` | SRA Toolkit not installed, not on `PATH`, or `vdb-config` never run | Install per above; run `vdb-config -i`; check `command -v fasterq-dump` |
| `fasterq-dump` exists but fails at runtime | SRA Toolkit not configured | Run `vdb-config -i` once |
| `axel not found` at startup | `axel` not installed | Optional: install it, or ignore — built-in FTP is used |
| `check-setup.sh` reports `FAIL sradownloader` | Wrong path / not cloned | Pass the path explicitly: `bash scripts/check-setup.sh /path/to/sradownloader` |
