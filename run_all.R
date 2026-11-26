# =============================================================================
#  Sovereign Wealth Funds and Post-Conflict Reconstruction:
#  The Qatari Model in Comparative Perspective  -  replication master script
#
#  Abdelhadi Benghalem, University Center of Maghnia (ERF)
#
#  Usage: open swf-post-conflict-reconstruction.Rproj (or setwd() to this
#  folder) and run   source("run_all.R")
#  Runtime: about 2-3 minutes from the frozen data snapshot.
# =============================================================================
REFRESH <- FALSE   # TRUE = re-download FTS and UNGA data (results may change)

ROOT <- normalizePath(getwd())
if (!file.exists(file.path(ROOT, "run_all.R")))
  stop("Set the working directory to the repository root (the folder containing run_all.R).")

source(file.path(ROOT, "code", "00_setup.R"))
if (REFRESH) source(file.path(ROOT, "code", "01_download_fts.R"))
source(file.path(ROOT, "code", "02_build_panel.R"))
source(file.path(ROOT, "code", "03_descriptives.R"))
source(file.path(ROOT, "code", "04_estimation.R"))
source(file.path(ROOT, "code", "05_paper_figures.R"))

writeLines(capture.output(sessionInfo()), file.path(DIR$log, "sessionInfo.txt"))
logf("\nDONE. Tables in output/tables, figures in output/figures, log in output/logs.")
