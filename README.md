# Sovereign Wealth Funds and Post-Conflict Reconstruction: The Qatari Model in Comparative Perspective

Replication package for the paper by **Abdelhadi Benghalem** (University Center of Maghnia, Tlemcen, Algeria; Research Associate, Economic Research Forum).

Presented at *The Economics of Conflict in the MENA Region*, Doha Institute for Graduate Studies, 23–24 November 2026.

The package reproduces every table and figure in the paper from public data, in about two minutes, with one command.

## Quick start

1. Install R (≥ 4.3) from <https://cran.r-project.org>.
2. Download or clone this repository.
3. Open `swf-post-conflict-reconstruction.Rproj` in RStudio or Positron, or set the working directory to the repository folder.
4. Run:

```r
source("run_all.R")
```

Missing packages (`data.table`, `fixest`, `ggplot2`, `httr2`, `jsonlite`) are installed automatically. Results are written to `output/`.

## What the package does

| Script | Purpose | Output |
|---|---|---|
| `run_all.R` | Master script: runs everything in order | — |
| `code/00_setup.R` | Packages, paths, logging, sample definition (9 donors, 8 recipients, 2014–2025) | — |
| `code/01_download_fts.R` | **Optional.** Rebuilds the raw data from the UN OCHA FTS and Harvard Dataverse APIs. Runs only if `REFRESH <- TRUE` | `data/raw/*` |
| `code/02_build_panel.R` | Cleans the flows, maps donors, merges UN voting alignment, builds the panel | `data/processed/*` |
| `code/03_descriptives.R` | Descriptive tables and diagnostic figures | `output/tables/T1–T5`, `output/figures/F1–F3` |
| `code/04_estimation.R` | PPML models, robustness, leave-one-out, Syria 2025 event estimates | `output/tables/T6–T9` |
| `code/05_paper_figures.R` | Figures 1–3 of the paper | `output/figures/Figure1–3` |

## Mapping to the paper

| Paper | File |
|---|---|
| Table 1 (deal ledger) | `data/deal_ledger/swf_deal_ledger.csv` |
| Table 2 (portfolios) | `output/tables/T2_donor_portfolio_concentration.csv`, `T5_official_vs_all_channels.csv` |
| Table 3 (determinants, PPML) | `output/tables/T6_main_models.csv` (`.tex`, `.txt`) |
| Table 4 (robustness) | `output/tables/T7_robustness.csv`, `T8_leave_one_recipient_out.csv` |
| Table 5 (Syria event estimates) | `output/tables/T9_syria_2025_event.csv` |
| Figure 1 (portfolio shares) | `output/figures/Figure1_portfolio_shares.png` |
| Figure 2 (funding to Syria) | `output/figures/Figure2_syria_funding.png` |
| Figure 3 (event estimate and placebos) | `output/figures/Figure3_event_placebos.png` |
| Section 4.1 (data validation) | `data/raw/fts_completeness_check.csv`, `output/logs/validation_log.txt` |

## Data

### Frozen snapshot (used by default)

FTS records are revised continuously. To make the results exactly reproducible, the package ships the data as downloaded on **19 November 2026**:

| File | Content | Source |
|---|---|---|
| `data/raw/fts_flows_raw_parsed.csv` | All 74,084 funding flows recorded by FTS for the eight recipients, 2014–2025, one row per flow and usage year, before any filtering | UN OCHA Financial Tracking Service API |
| `data/raw/fts_completeness_check.csv` | Flow counts and incoming totals reported by FTS for each recipient-year, compared with the parsed data (all 96 recipient-years complete) | Same |
| `data/raw/unga_agreement_subset.csv` | UN General Assembly voting agreement and ideal-point distance for every dyad among the 16 countries in the sample, 1946–2024 | Bailey, Strezhnev & Voeten, Harvard Dataverse |
| `data/deal_ledger/swf_deal_ledger.csv` | Hand-collected sovereign and state-linked Gulf deals in the eight recipients, each with two sources | Author, from company, fund and government statements |

`data/processed/` contains the cleaned flows and the donor × recipient × year panel produced by `02_build_panel.R`. Both are regenerated on each run. Variable definitions are in [`docs/codebook.md`](docs/codebook.md).

### Refreshing the data

Set `REFRESH <- TRUE` at the top of `run_all.R` to download everything again (about 30–40 minutes, ~450 API pages). A fresh download reflects later FTS revisions, so results can differ slightly from the paper.

### Data sources and terms of use

- **UN OCHA Financial Tracking Service (FTS)**, public API, <https://fts.unocha.org>. Accessed 19 November 2026. Use is subject to OCHA's terms; please cite FTS when using these data.
- **Bailey, M. A., Strezhnev, A., & Voeten, E. (2017).** Estimating dynamic state preferences from United Nations voting data. *Journal of Conflict Resolution*, 61(2), 430–456. Data: Harvard Dataverse, <https://doi.org/10.7910/DVN/LEJUQZ>.

## Estimation details

- **Estimator:** Poisson pseudo-maximum likelihood (`fixest::fepois`), which keeps the 20% of zero flows.
- **Determinants (Table 3):** donor × year and recipient × year fixed effects; standard errors clustered by donor–recipient pair (63 clusters); 2015–2024; Palestine excluded because it does not vote in the General Assembly.
- **Syria event (Table 5):** pair, donor × year and recipient × year fixed effects on 2015–2025. Inference rests on placebo estimates for every other donor in Syria and for Qatar in every other recipient.
- **Known limitation:** the UAE × Syria × 2025 placebo is not identified because the UAE recorded no official flow to Syria in 2025; its coefficient is numerically unstable across platforms and is not reported in the paper.

## Computational environment

Results in the paper were produced with R 4.5.3 (Windows), `fixest` 0.14.2, `data.table` 1.18.6.1 and `ggplot2` 4.0.3, and were re-verified on Linux with R 4.4. The tables match to 14 decimal places across both platforms. The full session information is written to `output/logs/sessionInfo.txt` on each run.

## Citation

> Benghalem, A. (2026). *Sovereign Wealth Funds and Post-Conflict Reconstruction: The Qatari Model in Comparative Perspective.* Paper presented at The Economics of Conflict in the MENA Region Conference, Doha Institute for Graduate Studies, 23–24 November 2026.

Machine-readable citation: [`CITATION.cff`](CITATION.cff).

## License

Code: MIT ([`LICENSE`](LICENSE)). Data in `data/raw/` remain subject to the terms of their original providers.

## Contact

Abdelhadi Benghalem · a.benghalem@cu-maghnia.dz · ORCID [0000-0003-4057-7448](https://orcid.org/0000-0003-4057-7448)
