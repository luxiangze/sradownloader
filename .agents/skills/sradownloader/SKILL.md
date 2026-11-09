---
name: sradownloader
description: Download raw FASTQ files from SRA via ENA or NCBI using sradownloader (v3.11-mod fork). Use when the user asks to download sequencing data by SRR/ERR accession, SraRunTable.txt, or an accession list; also for checking download results, resuming interrupted or failed downloads, and troubleshooting ENA, NCBI, fasterq-dump, or GEO name-lookup failures.
---

# sradownloader — download SRA data

`sradownloader` is a single-file Python script (repo root, `VERSION = "3.11-mod"`)
that downloads raw FASTQ files for SRA runs, trying ENA first and falling back
to NCBI. It needs only Python 3 (standard library); `fasterq-dump` and `gzip`
are needed only for the NCBI fallback, and `axel` is an optional accelerator
for ENA downloads. For installing or fixing prerequisites, use the
`sradownloader-setup` skill instead.

## Quick start

```bash
# Verify the program first (expect: SRA downloader v3.11-mod)
./sradownloader --version

# One run
./sradownloader SRR5413015

# A whole study from the SRA Run Selector table
./sradownloader SraRunTable.txt --outdir ./fastq
```

After a fresh `git clone` the file may not be executable (it is stored with
mode 644); run `chmod +x sradownloader` once, or invoke it as
`python3 sradownloader ...`.

## Inputs — three forms

1. **SraRunTable.txt** — the CSV exported from the SRA Run Selector. The
   header row starts with `Run`; the `source_name` column is used as the
   sample-name fallback (see Naming below). Repeated header rows mid-file
   are skipped.
2. **Accession list** — a plain text file, one `SRR...` / `ERR...` per line.
3. **Bare accession** — a single `SRR...` / `ERR...` on the command line.

## How a download proceeds (per sample, one at a time)

Samples are streamed one at a time: each sample is resolved and downloaded
before the next one is even looked up, so output starts immediately and a
long list does not wait on slow name lookups.

1. **Naming.** The sample name is fetched from GEO
   (`https://www.ncbi.nlm.nih.gov/sra/?term=<accession>&format=text`, the
   `Title:` line), unless `--nogeo` is given. If GEO yields nothing, the
   `source_name` column is used. Characters in
   `space / > < | " ? * ( ) \ [ ] { } ! & #` are replaced with `_`,
   repeated `_` are collapsed, and the name is prefixed with `_`.
   Output base name: `<accession>_<sample_name>`.
   If a file matching `<accession>*.fastq.gz` already exists in the output
   directory and `--force` is not set, the GEO lookup is skipped and the
   existing file's base name is reused.
2. **ENA first.** The ENA portal API is queried for the run's `fastq_ftp`
   URLs (30 s timeout). Each URL is downloaded as
   `<file_base>_1.fastq.gz` / `<file_base>_2.fastq.gz`. If `axel` is
   installed it is auto-detected at startup and used
   (`axel -n <axel-threads> -o <outfile> ftp://...`); otherwise the
   built-in FTP downloader runs with a live speed / percentage progress
   bar and a NOOP keep-alive on the control channel.
3. **NCBI fallback.** If ENA fails for a sample, `fasterq-dump` is run:
   `fasterq-dump --split-files --include-technical --threads <n>
   --temp <outdir> --outfile <file_base>.fastq [--outdir <outdir>]
   <accession>`, then each downloaded `.fastq` is compressed with
   `gzip -4`. This path is skipped entirely with `--noncbi`; if ENA is
   also disabled (`--noena`), the run aborts with an error.
4. **Retries.** Each failed attempt deletes the partial file, waits
   `min(attempt^2, 30)` seconds, and retries, up to `--retries`
   (default 5) times.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `runtable` (positional) | — | SraRunTable.txt, accession list, or bare SRR/ERR accession |
| `--outdir` | `.` | Folder for output (created if missing) |
| `--threads` | 1 | Threads for `fasterq-dump` (NCBI path only; ENA is unaffected) |
| `--retries` | 5 | Attempts per file before giving up |
| `--force` | off | Overwrite existing output files (a flag in this fork) |
| `--fqdump` | `fasterq-dump` | Path to the fasterq-dump binary |
| `--axel-threads` | 16 | Connections per `axel` download (ENA path, only if axel is installed) |
| `--nogeo` | off | Skip the GEO sample-name lookup |
| `--noena` | off | Do not try ENA (NCBI only) |
| `--noncbi` | off | Do not try NCBI (ENA only) |
| `--quiet` | off | Suppress all but essential messages |
| `--version` | — | Print `SRA downloader v3.11-mod` and exit |

## Common commands

```bash
# ENA only (no SRA Toolkit needed), 16 axel connections
./sradownloader SraRunTable.txt --outdir ./fastq --noncbi

# NCBI only (e.g. ENA has no files for these runs)
./sradownloader SraRunTable.txt --outdir ./fastq --noena --threads 4

# Re-run after an interruption: already-finished files are skipped,
# failed ones are retried. Add --force to re-download everything.
./sradownloader SraRunTable.txt --outdir ./fastq

# Quiet, for logs
./sradownloader SraRunTable.txt --outdir ./fastq --quiet
```

## Checking results

- At the end (and also after Ctrl-C, if anything finished) the program
  prints a `RESULTS` table and writes
  `<outdir>/sradownloader_results.txt` with one `ACCESSION<TAB>RESULT`
  line per sample (`SUCCEEDED` / `FAILED`).
- The process exit code is **0 even when individual samples failed** —
  always read `sradownloader_results.txt` (or the printed table) instead
  of trusting the exit code. The only hard failure is exit 1 when both
  ENA and NCBI are unavailable.
- To retry only the failures, re-run the same command: finished files are
  skipped, failed accessions are attempted again. Or build a small list
  from the `FAILED` lines in the results file and pass it as the input.

## Before a big run

- Check free disk first (`df -h <outdir>`): SRA downloads are routinely
  tens of GB. ENA files arrive already gzipped; the NCBI path downloads
  uncompressed FASTQ and then gzips it, so it briefly needs roughly twice
  the final size.
- Do not run two instances into the same `--outdir`: a retry deletes
  partial files, so concurrent runs can delete each other's downloads.
- `--threads` does not speed up ENA downloads; ENA speed comes from
  `axel` (`--axel-threads`) or the built-in FTP downloader.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `axel not found — using built-in FTP downloader` at startup | `axel` is not installed | Optional: install it (`sradownloader-setup` skill), or ignore — the built-in downloader works |
| `WARNING: Couldn't find fasterq-dump ...` at startup | SRA Toolkit missing / not configured | ENA-only mode still works; for NCBI fallback install the toolkit and run `vdb-config -i` (see `sradownloader-setup`) |
| `ERROR: Both NCBI and ENA download options are unavailable` | `--noncbi` + `--noena`, or fasterq-dump missing with `--noena` | Drop one of the two flags, or install fasterq-dump |
| Sample `FAILED` via ENA, then `FAILED` via NCBI | Run genuinely unavailable, or network blocked | Check the accession on the SRA/ENA website; check network/proxy; re-run later — the same command resumes |
| `Found no accession in ENA REST response` | ENA has no FASTQ files for this run | Re-run with `--noena` to go straight to NCBI |
| GEO name lookup slow / warnings | NCBI SRA page slow or unreachable | Add `--nogeo` to use the `source_name` column instead; existing files skip the lookup anyway |
| Output files are `_1.fastq.gz` only, or `_2` missing | Single-end run, or ENA lists one file | Expected for single-end data; verify against the run's layout on SRA |
| Run interrupted with Ctrl-C | — | Safe: results so far are in `sradownloader_results.txt`; re-run the same command to resume |
