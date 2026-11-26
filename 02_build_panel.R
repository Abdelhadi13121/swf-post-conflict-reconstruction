# =============================================================================
# 02_build_panel.R  -  clean FTS flows, map donors, merge UNGA alignment,
#                      build the donor x recipient x year panel
# Input : data/raw/fts_flows_raw_parsed.csv, data/raw/fts_completeness_check.csv,
#         data/raw/unga_agreement_subset.csv
# Output: data/processed/fts_flows_sample_clean.csv,
#         data/processed/panel_donor_recipient_year.csv
# =============================================================================
logf("\n== 02: building the panel ==")
flows <- fread(file.path(DIR$raw, "fts_flows_raw_parsed.csv"),
               colClasses = list(character = c("flow_id", "src_org", "src_orgtype", "src_loc",
                                               "dst_org", "dst_loc", "on_boundary", "flow_type",
                                               "status", "boundary", "date", "recipient")))
flows[, new_money := as.logical(new_money)]
flows[src_loc == "", src_loc := NA_character_]

fts_check <- fread(file.path(DIR$raw, "fts_completeness_check.csv"), integer64 = "double")
logtab(fts_check[, .(recipient_years = .N, all_complete = all(count_ratio == 1),
                     median_usd_ratio = median(usd_ratio))],
       "FTS snapshot completeness (flow counts vs FTS-reported counts)")

# Audit trail of every filter step
audit <- data.table(step = "all flows parsed", n = nrow(flows),
                    usd_bn = sum(flows$amount_usd, na.rm = TRUE) / 1e9)
step  <- function(d, lab) {
  audit <<- rbind(audit, data.table(step = lab, n = nrow(d),
                  usd_bn = sum(d$amount_usd, na.rm = TRUE) / 1e9)); d }

logtab(flows[, .N, by = status], "Flow status values")
logtab(flows[, .N, by = boundary], "Boundary values")
logtab(flows[, .N, by = flow_type], "Flow type values")
f1 <- step(flows[boundary == "incoming"], "boundary == incoming")
f1 <- step(f1[status %in% c("paid", "commitment")], "status paid/commitment (pledges dropped)")
f1 <- step(f1[is.na(flow_type) | flow_type == "Standard"], "flowType Standard (carry-overs dropped)")
f1 <- step(f1[is.na(new_money) | new_money == TRUE], "newMoney (no pass-through double counting)")
f1 <- step(f1[!is.na(amount_usd) & amount_usd > 0], "positive USD amount")
setorder(f1, flow_id, year)
f1 <- step(unique(f1, by = c("flow_id", "recipient")), "dedup multi-year flows (first usage year)")

# Map source to donor country
f1[, donor := NA_character_]
for (i in seq_len(nrow(DONORS)))
  f1[is.na(donor) & !is.na(src_loc) & grepl(DONORS$rx[i], src_loc, perl = TRUE),
     donor := DONORS$donor[i]]
# Fallback when FTS gives no source Location: government org name
for (i in seq_len(nrow(DONORS)))
  f1[is.na(donor) & is.na(src_loc) &
     grepl(paste0("^", DONORS$name[i], ", Government of"), src_org),
     donor := DONORS$donor[i]]

# Official (government / public agency) vs all flows from the donor country
GOV_RX <- paste0("Government of|Fund for Development|Development Fund|King Salman|",
                 "KSrelief|Ministry|Agency for International Development|USAID|",
                 "Foreign|Commonwealth|DFID|FCDO|Kuwait Fund|Abu Dhabi Fund|",
                 "Saudi Fund|Qatar Fund|TIKA|AFAD|GIZ|KfW|Norad")
f1[, official := grepl("Government", src_orgtype) | grepl(GOV_RX, src_org)]
f1[, shared_dest := n_dst_loc > 1 | (!is.na(on_boundary) & on_boundary == "shared")]

logtab(audit, "Filter audit (flows, USD bn)")
logtab(f1[is.na(donor), .(usd_m = round(sum(amount_usd) / 1e6, 1)),
          by = src_loc][order(-usd_m)] |> head(30),
       "Top 30 UNMAPPED source locations (check no sample donor is missing)")
logtab(f1[!is.na(donor), .(n = .N, usd_m = round(sum(amount_usd) / 1e6, 1),
                           official_share = round(mean(official), 3),
                           shared_dest_share = round(mean(shared_dest), 3)),
          by = donor][order(-usd_m)], "Mapped donors: totals and flags")
logtab(f1[!is.na(donor) & !official,
          .(usd_m = round(sum(amount_usd) / 1e6, 1)), by = .(donor, src_org)][
          order(-usd_m)] |> head(25),
       "Largest NON-official sources by donor country (private, charities)")

# Sanity: top 5 sources of all funding per recipient (all donors, not only sample)
logtab(f1[, .(usd_m = round(sum(amount_usd) / 1e6)), by = .(recipient, src_loc)][
          order(recipient, -usd_m)][, head(.SD, 5), by = recipient],
       "Top 5 source countries per recipient, 2014-2025 (sanity check)")

fwrite(f1[!is.na(donor)], file.path(DIR$proc, "fts_flows_sample_clean.csv"))

## ---- 4. Donor x recipient x year panel --------------------------------------
agg <- f1[!is.na(donor), .(
  flow_off     = sum(amount_usd[official]) / 1e6,                   # USD m
  flow_all     = sum(amount_usd) / 1e6,
  flow_off_sgl = sum(amount_usd[official & !shared_dest]) / 1e6,
  flow_paid    = sum(amount_usd[official & status == "paid"]) / 1e6),
  by = .(donor, recipient, year)]

panel <- CJ(donor = DONORS$donor, recipient = RECIP$recipient, year = YEARS)
panel <- merge(panel, agg, by = c("donor", "recipient", "year"), all.x = TRUE)
for (v in c("flow_off", "flow_all", "flow_off_sgl", "flow_paid"))
  set(panel, which(is.na(panel[[v]])), v, 0)

## ---- 5. UNGA voting alignment (Bailey, Strezhnev & Voeten) ------------------
dy <- CJ(donor = DONORS$donor, recipient = RECIP$recipient)
dy <- merge(dy, DONORS[, .(donor, cow_d = cow)], by = "donor")
dy <- merge(dy, RECIP[, .(recipient, cow_r = cow)], by = "recipient")
A  <- fread(file.path(DIR$raw, "unga_agreement_subset.csv"))
A  <- A[, .(c1 = as.integer(ccode1), c2 = as.integer(ccode2), year = as.integer(year),
            agree = as.numeric(agree), ipd = as.numeric(IdealPointDistance))]
A  <- rbind(A, A[, .(c1 = c2, c2 = c1, year, agree, ipd)])     # both orders
A  <- unique(A, by = c("c1", "c2", "year"))
align <- merge(dy, A, by.x = c("cow_d", "cow_r"), by.y = c("c1", "c2"))
align <- align[, .(donor, recipient, year, agree, ipd)]
logtab(align[, .(years = paste(range(year), collapse = "-"),
                 n = .N, mean_agree = round(mean(agree, na.rm = TRUE), 3)), by = donor],
       "UNGA alignment coverage by donor")

# One-year lag: votes in session t-1 explain funding in year t
align[, year := year + 1L]
setnames(align, c("agree", "ipd"), c("agree_l1", "ipd_l1"))
panel <- merge(panel, align, by = c("donor", "recipient", "year"), all.x = TRUE)

## ---- 6. Covariates ----------------------------------------------------------
hav <- function(la1, lo1, la2, lo2) {
  r <- pi / 180; a <- sin((la2 - la1) * r / 2)^2 +
    cos(la1 * r) * cos(la2 * r) * sin((lo2 - lo1) * r / 2)^2
  2 * 6371 * asin(sqrt(a))
}
panel <- merge(panel, DONORS[, .(donor, gulf, arab_d = arab, lat_d = lat, lon_d = lon)], by = "donor")
panel <- merge(panel, RECIP[, .(recipient, arab_r = arab, lat_r = lat, lon_r = lon)], by = "recipient")
panel[, log_dist := log(hav(lat_d, lon_d, lat_r, lon_r))]
# Arab League co-membership; Syria suspended Nov 2011 - May 2023
panel[, arab_common := as.integer(arab_d == 1 & arab_r == 1 &
                                  !(recipient == "SYR" & year <= 2022))]
panel[, qatar := as.integer(donor == "QAT")]
panel[, pair := paste(donor, recipient, sep = "_")]
panel[, c("lat_d", "lon_d", "lat_r", "lon_r") := NULL]
fwrite(panel, file.path(DIR$proc, "panel_donor_recipient_year.csv"))

logtab(panel[year %in% EST_YEARS & recipient != "PSE",
             .(obs = .N, zero_share = round(mean(flow_off == 0), 3),
               miss_align = sum(is.na(agree_l1)))], "Estimation panel summary")
