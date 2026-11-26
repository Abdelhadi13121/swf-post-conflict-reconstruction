# =============================================================================
# 04_estimation.R  -  PPML models (Tables 3-4), leave-one-out, Syria event (Table 5)
# Input : data/processed/panel_donor_recipient_year.csv (object `panel`)
# =============================================================================
if (!exists("panel")) panel <- fread(file.path(DIR$proc, "panel_donor_recipient_year.csv"))
## ---- 8. Estimation (PPML, fixest) -------------------------------------------
logf("\n== Step 8: estimation ==")
est <- panel[year %in% EST_YEARS & recipient != "PSE" & !is.na(agree_l1)]
logf("Estimation sample: ", nrow(est), " obs, ", uniqueN(est$pair), " pairs, years ",
     paste(range(est$year), collapse = "-"))

safe <- function(expr, lab) tryCatch(expr, error = function(e) {
  logf("MODEL FAILED [", lab, "]: ", conditionMessage(e)); NULL })
CL <- ~pair

M <- list()
M$m1 <- safe(fepois(flow_off ~ agree_l1 + log_dist + arab_common |
                      donor^year + recipient^year, est, cluster = CL), "m1")
M$m2 <- safe(fepois(flow_off ~ agree_l1 + arab_common |
                      pair + donor^year + recipient^year, est, cluster = CL), "m2")
M$m3 <- safe(fepois(flow_off ~ agree_l1 + agree_l1:gulf + log_dist + arab_common |
                      donor^year + recipient^year, est, cluster = CL), "m3")
M$m4 <- safe(fepois(flow_off ~ agree_l1 + agree_l1:qatar + log_dist + arab_common |
                      donor^year + recipient^year, est, cluster = CL), "m4")
M$m5 <- safe(fepois(flow_off ~ ipd_l1 + log_dist + arab_common |
                      donor^year + recipient^year, est[!is.na(ipd_l1)], cluster = CL), "m5")

R <- list()   # robustness on the m1 specification
f_m1 <- function(y) as.formula(paste(y, "~ agree_l1 + log_dist + arab_common | donor^year + recipient^year"))
R$r1_all_channels <- safe(fepois(f_m1("flow_all"),     est, cluster = CL), "r1")
R$r2_paid_only    <- safe(fepois(f_m1("flow_paid"),    est, cluster = CL), "r2")
R$r3_single_dest  <- safe(fepois(f_m1("flow_off_sgl"), est, cluster = CL), "r3")
R$r4_no_afg       <- safe(fepois(f_m1("flow_off"), est[recipient != "AFG"], cluster = CL), "r4")
R$r5_no_covid     <- safe(fepois(f_m1("flow_off"), est[!year %in% 2020:2021], cluster = CL), "r5")
R$r6_gulf_only    <- safe(fepois(f_m1("flow_off"), est[gulf == 1], cluster = CL), "r6")
R$r7_twoway_cl    <- safe(fepois(f_m1("flow_off"), est, cluster = ~donor + recipient), "r7")

LOO <- rbindlist(lapply(unique(est$recipient), function(r) {
  m <- safe(fepois(f_m1("flow_off"), est[recipient != r], cluster = CL), paste("loo", r))
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  data.table(dropped = r, b = ct["agree_l1", 1], se = ct["agree_l1", 2], p = ct["agree_l1", 4])
}))
fwrite(LOO, file.path(DIR$tab, "T8_leave_one_recipient_out.csv"))
logtab(LOO, "Leave-one-recipient-out (agree_l1)")

tidy_fx <- function(lst) rbindlist(lapply(names(lst), function(n) {
  m <- lst[[n]]; if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  data.table(model = n, term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
             p = ct[, 4], nobs = nobs(m),
             pseudo_r2 = tryCatch(as.numeric(fitstat(m, "pr2")), error = function(e) NA_real_))
}))
T6 <- tidy_fx(M); T7 <- tidy_fx(R)
fwrite(T6, file.path(DIR$tab, "T6_main_models.csv"))
fwrite(T7, file.path(DIR$tab, "T7_robustness.csv"))
logtab(T6, "Main models"); logtab(T7, "Robustness")

ok <- Filter(Negate(is.null), M)
if (length(ok)) {
  etable(ok, tex = TRUE, file = file.path(DIR$tab, "T6_main_models.tex"), replace = TRUE)
  capture.output(etable(ok), file = file.path(DIR$tab, "T6_main_models.txt"))
}
okr <- Filter(Negate(is.null), R)
if (length(okr)) capture.output(etable(okr), file = file.path(DIR$tab, "T7_robustness.txt"))

# Economic magnitude: % change in funding for +0.10 voting agreement
if (!is.null(M$m1)) {
  b <- coef(M$m1)["agree_l1"]
  logf("Magnitude: +0.10 agreement -> ", round(100 * (exp(0.10 * b) - 1), 1), "% official funding")
}

## ---- 8b. Syria after December 2024: event estimates --------------------------
# PPML with pair, donor-year and recipient-year FE on 2015-2025 (all 8 recipients).
# D = treated donor x Syria x 2025. Placebos: Qatar x other recipients; other donors x Syria.
logf("\n== Step 8b: Syria 2025 event ==")
ev <- panel[year %in% 2015:2025]
ev_est <- function(td, rec = "SYR", y = "flow_off", yr = 2025) {
  d <- copy(ev)[, D := as.integer(donor %in% td & recipient == rec & year == yr)]
  m <- safe(fepois(as.formula(paste(y, "~ D | pair + donor^year + recipient^year")), d,
                   cluster = ~pair), paste("event", paste(td, collapse = "+"), rec, y, yr))
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  data.table(treated = paste(td, collapse = "+"), recipient = rec, outcome = y, year = yr,
             b = ct["D", 1], se = ct["D", 2], p = ct["D", 4], ratio = exp(ct["D", 1]))
}
EV <- rbindlist(c(
  list(ev_est("QAT"), ev_est(c("QAT", "SAU", "TUR")), ev_est(c("QAT", "SAU", "TUR", "ARE", "KWT")),
       ev_est("QAT", y = "flow_paid"), ev_est("QAT", y = "flow_all"),
       ev_est("QAT", yr = 2023), ev_est("QAT", yr = 2024)),
  lapply(setdiff(RECIP$recipient, "SYR"), function(r) ev_est("QAT", rec = r)),
  lapply(setdiff(DONORS$donor, "QAT"), function(dn) ev_est(dn))))
fwrite(EV, file.path(DIR$tab, "T9_syria_2025_event.csv"))
logtab(EV[, .(treated, recipient, outcome, year, b = round(b, 2), p = round(p, 4), ratio = round(ratio, 1))],
       "Syria 2025 event estimates and placebos")

