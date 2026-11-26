# =============================================================================
# 00_setup.R  -  packages, paths, logging helpers, sample definition
# Sourced by run_all.R. Do not run on its own.
# =============================================================================
pkgs <- c("data.table", "fixest", "ggplot2", "httr2", "jsonlite")
miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) install.packages(miss, repos = "https://cloud.r-project.org")
suppressPackageStartupMessages({
  library(data.table); library(fixest); library(ggplot2)
})

DIR <- list(raw  = file.path(ROOT, "data", "raw"),
            proc = file.path(ROOT, "data", "processed"),
            tab  = file.path(ROOT, "output", "tables"),
            fig  = file.path(ROOT, "output", "figures"),
            log  = file.path(ROOT, "output", "logs"),
            cache = file.path(ROOT, "data", "raw", "fts_json"))   # only used by 01
invisible(lapply(DIR[c("proc", "tab", "fig", "log")], dir.create, recursive = TRUE, showWarnings = FALSE))

LOG <- file.path(DIR$log, "validation_log.txt")
if (!exists("LOG_STARTED")) { cat("Run:", format(Sys.time()), "\n", file = LOG); LOG_STARTED <- TRUE }
logf <- function(...) { txt <- paste0(...); cat(txt, "\n"); cat(txt, "\n", file = LOG, append = TRUE) }
logtab <- function(x, title) {
  logf("\n### ", title)
  out <- capture.output(print(x, nrows = 200, class = FALSE))
  cat(out, sep = "\n"); cat(out, sep = "\n", file = LOG, append = TRUE)
}

## ---- 1. Sample definition ---------------------------------------------------
YEARS <- 2014:2025          # 2025 kept for descriptives (post-Assad Syria)
EST_YEARS <- 2015:2024      # estimation window (alignment lagged one year)

DONORS <- data.table(
  donor  = c("QAT", "SAU", "ARE", "KWT", "TUR", "NOR", "DEU", "GBR", "USA"),
  name   = c("Qatar", "Saudi Arabia", "United Arab Emirates", "Kuwait",
             "Turkiye", "Norway", "Germany", "United Kingdom", "United States"),
  # regex matched against the FTS source *Location* name
  rx     = c("^Qatar$", "^Saudi Arabia$", "United Arab Emirates", "^Kuwait$",
             "^T.{1,2}rk(ey|iye)", "^Norway$", "^Germany$",
             "United Kingdom", "United States"),
  cow    = c(694, 670, 696, 690, 640, 385, 255, 200, 2),
  gulf   = c(1, 1, 1, 1, 0, 0, 0, 0, 0),
  arab   = c(1, 1, 1, 1, 0, 0, 0, 0, 0),
  lat    = c(25.29, 24.71, 24.45, 29.38, 39.93, 59.91, 52.52, 51.51, 38.90),
  lon    = c(51.53, 46.68, 54.38, 47.99, 32.86, 10.75, 13.40, -0.13, -77.04)
)
RECIP <- data.table(
  recipient = c("SYR", "IRQ", "LBY", "YEM", "PSE", "AFG", "SDN", "SOM"),
  rname     = c("Syria", "Iraq", "Libya", "Yemen", "Palestine (oPt)",
                "Afghanistan", "Sudan", "Somalia"),
  cow       = c(652, 645, 620, 679, NA, 700, 625, 520),  # PSE: no UNGA vote
  arab      = c(1, 1, 1, 1, 1, 0, 1, 1),
  lat       = c(33.51, 33.31, 32.89, 15.37, 31.90, 34.56, 15.50, 2.05),
  lon       = c(36.29, 44.36, 13.19, 44.19, 35.20, 69.21, 32.56, 45.32)
)

