# =============================================================================
# 01_download_fts.R  -  OPTIONAL: rebuild the raw data snapshot from the APIs
#
# Not needed to replicate the paper: run_all.R uses the frozen snapshot in
# data/raw/ (FTS downloaded 19 November 2026). Run this only with
# REFRESH <- TRUE in run_all.R. FTS records are revised over time, so a fresh
# download can differ slightly from the published results.
# Writes: data/raw/fts_flows_raw_parsed.csv, data/raw/fts_completeness_check.csv,
#         data/raw/unga_agreement_subset.csv
# =============================================================================
suppressPackageStartupMessages({ library(httr2); library(jsonlite) })
dir.create(DIR$cache, recursive = TRUE, showWarnings = FALSE)
DIR$raw_fts <- DIR$cache
## ---- 2. Download FTS flows --------------------------------------------------
# The FTS API returns 200 flows per page and a meta$nextLink to the next page.
# Every page is fetched and cached (ISO_YEAR_pN.json). A file named ISO_YEAR.json
# from the first (unpaginated) run is reused as page 1.
fts_page <- function(url, f) {
  if (file.exists(f) && file.size(f) > 200) return(f)            # cached
  resp <- request(url) |>
    req_user_agent("academic research - University Center of Maghnia") |>
    req_timeout(120) |>
    req_retry(max_tries = 6, backoff = function(i) 10 * i) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()
  if (resp_status(resp) != 200) {
    logf("WARNING FTS ", basename(f), ": HTTP ", resp_status(resp)); return(NA_character_)
  }
  writeLines(resp_body_string(resp), f, useBytes = TRUE)
  Sys.sleep(1)                                                    # be polite
  f
}
fts_get <- function(iso3, yr) {
  old <- file.path(DIR$raw_fts, sprintf("%s_%d.json", iso3, yr))
  p1  <- file.path(DIR$raw_fts, sprintf("%s_%d_p1.json", iso3, yr))
  if (file.exists(old) && !file.exists(p1)) file.rename(old, p1)
  url <- sprintf("https://api.hpc.tools/v1/public/fts/flow?countryISO3=%s&year=%d", iso3, yr)
  files <- character(0); k <- 1
  repeat {
    f <- fts_page(url, file.path(DIR$raw_fts, sprintf("%s_%d_p%d.json", iso3, yr, k)))
    if (is.na(f)) break
    files <- c(files, f)
    nx <- fromJSON(f, simplifyVector = FALSE)$meta$nextLink
    if (is.null(nx) || !nzchar(nx) || k >= 100) break
    url <- nx; k <- k + 1
  }
  if (k %% 5 == 0 || is.null(nx)) message(iso3, " ", yr, ": ", length(files), " page(s)")
  files
}
fts_meta <- function(f) {               # FTS's own reported totals (page 1)
  m <- fromJSON(f, simplifyVector = FALSE)
  data.table(meta_count = as.numeric(nfld0(m$meta$count)),
             fts_incoming_usd = as.numeric(nfld0(m$data$incoming$fundingTotal)))
}
nfld0 <- function(x) if (is.null(x)) NA else x

logf("== Step 2: downloading FTS, all pages (", nrow(RECIP) * length(YEARS), " recipient-years) ==")
grid  <- CJ(recipient = RECIP$recipient, year = YEARS)
pages <- rbindlist(Map(function(r, y) {
  fs <- fts_get(r, y)
  if (!length(fs)) return(data.table(recipient = r, year = y, file = NA_character_, page = NA_integer_))
  data.table(recipient = r, year = y, file = fs, page = seq_along(fs))
}, grid$recipient, grid$year))
if (anyNA(pages$file)) logtab(pages[is.na(file)], "FTS recipient-years that failed")
fts_check <- cbind(pages[page == 1, .(recipient, year, n_pages = NA_integer_)],
                   rbindlist(lapply(pages[page == 1, file], fts_meta)))
fts_check[, n_pages := pages[, .N, by = .(recipient, year)]$N]
grid <- pages[!is.na(file)]

## ---- 3. Parse FTS flows (defensive: schema checked, not assumed) ------------
pick <- function(objs, type, field) {
  v <- unlist(lapply(objs, function(o)
    if (identical(o$type, type)) o[[field]] else NULL), use.names = FALSE)
  if (length(v)) paste(unique(v), collapse = " | ") else NA_character_
}
nfld <- function(x) if (is.null(x)) NA else x

parse_fts <- function(f, iso3, yr) {
  js <- fromJSON(f, simplifyVector = FALSE)
  fl <- js$data$flows
  if (is.null(fl)) stop("Unexpected FTS schema in ", f,
                        ". Top-level names: ", paste(names(js$data), collapse = ", "),
                        "  -> send this message to Claude.")
  if (!length(fl)) return(NULL)
  rbindlist(lapply(fl, function(x) data.table(
    flow_id     = as.character(nfld(x$id)),
    amount_usd  = as.numeric(nfld(x$amountUSD)),
    status      = nfld(x$status),
    boundary    = nfld(x$boundary),
    on_boundary = nfld(x$onBoundary),
    flow_type   = nfld(x$flowType),
    new_money   = as.logical(nfld(x$newMoney)),
    date        = nfld(x$date),
    src_org     = pick(x$sourceObjects, "Organization", "name"),
    src_orgtype = paste(unlist(lapply(x$sourceObjects, function(o)
                    if (identical(o$type, "Organization")) o$organizationTypes)),
                    collapse = " | "),
    src_loc     = pick(x$sourceObjects, "Location", "name"),
    dst_org     = pick(x$destinationObjects, "Organization", "name"),
    dst_loc     = pick(x$destinationObjects, "Location", "name"),
    n_dst_loc   = sum(vapply(x$destinationObjects,
                    function(o) identical(o$type, "Location"), logical(1))),
    recipient   = iso3,
    year        = yr)), fill = TRUE)
}

logf("== Step 3: parsing ==")
flows <- rbindlist(Map(parse_fts, grid[!is.na(file), file],
                       grid[!is.na(file), recipient], grid[!is.na(file), year]),
                   fill = TRUE)
fwrite(flows, file.path(DIR$raw, "fts_flows_raw_parsed.csv"))

logtab(flows[, .N, by = status], "Flow status values")
logtab(flows[, .N, by = boundary], "Boundary values")
logtab(flows[, .N, by = flow_type], "Flow type values")

# Completeness check against FTS's own totals: every flow downloaded?
got <- unique(flows, by = c("flow_id", "recipient", "year"))[
  , .(n_parsed = .N,
      parsed_incoming_usd = sum(amount_usd[boundary == "incoming" & status != "pledge" &
                                           (is.na(flow_type) | flow_type != "Parked")], na.rm = TRUE)),
  by = .(recipient, year)]
fts_check <- merge(fts_check, got, by = c("recipient", "year"), all.x = TRUE)
fts_check[, `:=`(count_ratio = round(n_parsed / meta_count, 3),
                 usd_ratio   = round(parsed_incoming_usd / fts_incoming_usd, 3))]
fwrite(fts_check, file.path(DIR$raw, "fts_completeness_check.csv"))
logtab(fts_check[, .(recipient, year, n_pages, meta_count, n_parsed, count_ratio,
                     fts_incoming_bn = round(fts_incoming_usd / 1e9, 2), usd_ratio)],
       "FTS completeness: parsed vs FTS-reported (count_ratio should be 1.000)")
if (any(fts_check$count_ratio < 0.99, na.rm = TRUE))
  logf("WARNING: some recipient-years are incomplete - see data/raw/fts_completeness_check.csv")

## ---- UNGA voting data (Bailey, Strezhnev & Voeten, Harvard Dataverse) ---------
# Downloads AgreementScores.csv (~145 MB) and keeps only the dyads used here.
logf("\n== UNGA voting data ==")
ds <- request(paste0("https://dataverse.harvard.edu/api/datasets/:persistentId/",
                     "?persistentId=doi:10.7910/DVN/LEJUQZ")) |>
  req_timeout(120) |> req_retry(max_tries = 4) |> req_perform() |> resp_body_json()
fl <- rbindlist(lapply(ds$data$latestVersion$files, function(f) data.table(
  id = f$dataFile$id,
  fn = if (!is.null(f$dataFile$originalFileName)) f$dataFile$originalFileName else f$dataFile$filename)))
id <- fl[fn == "AgreementScores.csv", id][1]
tmp <- file.path(DIR$cache, "AgreementScores.csv")
if (!file.exists(tmp))
  request(sprintf("https://dataverse.harvard.edu/api/access/datafile/%s?format=original", id)) |>
    req_timeout(1800) |> req_retry(max_tries = 4) |> req_perform(path = tmp)
A <- fread(tmp, select = c("ccode1", "ccode2", "year", "agree", "IdealPointDistance"))
codes <- c(DONORS$cow, RECIP$cow[!is.na(RECIP$cow)])
A <- A[ccode1 %in% codes & ccode2 %in% codes]
fwrite(A, file.path(DIR$raw, "unga_agreement_subset.csv"))
logf("UNGA subset written: ", nrow(A), " dyad-years")
