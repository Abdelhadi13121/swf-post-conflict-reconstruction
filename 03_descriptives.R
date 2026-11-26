# =============================================================================
# 03_descriptives.R  -  Tables 1-5 (CSV) and diagnostic figures F1-F3
# Input : data/processed/panel_donor_recipient_year.csv (object `panel`)
# =============================================================================
if (!exists("panel")) panel <- fread(file.path(DIR$proc, "panel_donor_recipient_year.csv"))
## ---- 7. Descriptive results -------------------------------------------------
logf("\n== Step 7: descriptives ==")
D1 <- dcast(panel[year %in% 2014:2024, .(usd_m = round(sum(flow_off), 1)),
                  by = .(donor, recipient)], donor ~ recipient, value.var = "usd_m")
D1[, TOTAL := rowSums(.SD), .SDcols = RECIP$recipient]
fwrite(D1, file.path(DIR$tab, "T1_official_flows_donor_by_recipient_2014_2024.csv"))

D2 <- panel[year %in% 2014:2024, .(usd_m = sum(flow_off)), by = .(donor, recipient)][
  , share := usd_m / sum(usd_m), by = donor][
  , .(total_usd_m = round(sum(usd_m), 1),
      top_recipient = recipient[which.max(share)],
      top_share = round(max(share), 3),
      hhi = round(sum(share^2), 3),
      arab_recipient_share = round(sum(share[recipient %in% RECIP[arab == 1, recipient]]), 3)),
  by = donor][order(-total_usd_m)]
fwrite(D2, file.path(DIR$tab, "T2_donor_portfolio_concentration.csv"))
logtab(D2, "Donor portfolio concentration 2014-2024")

D3 <- dcast(panel[recipient == "SYR", .(usd_m = round(flow_off, 1)), by = .(donor, year)],
            year ~ donor, value.var = "usd_m")
fwrite(D3, file.path(DIR$tab, "T3_syria_official_flows_by_year_2014_2025.csv"))

D4 <- panel[, .(usd_m = round(sum(flow_off), 1), usd_all = round(sum(flow_all), 1)),
            by = .(donor, year)]
fwrite(dcast(D4, year ~ donor, value.var = "usd_m"),
       file.path(DIR$tab, "T4_official_flows_by_donor_year.csv"))

# Official vs all (charities / private) by donor: the "ecosystem" channel
D5 <- panel[year %in% 2014:2024, .(official = round(sum(flow_off), 1),
                                   all_sources = round(sum(flow_all), 1)), by = donor][
  , nonofficial_share := round(1 - official / all_sources, 3)][order(-all_sources)]
fwrite(D5, file.path(DIR$tab, "T5_official_vs_all_channels.csv"))
logtab(D5, "Official vs all channels by donor country")

theme_set(theme_minimal(base_size = 11))
hm <- panel[year %in% 2014:2024, .(usd_m = sum(flow_off)), by = .(donor, recipient)]
g1 <- ggplot(hm, aes(recipient, donor, fill = log1p(usd_m))) + geom_tile(colour = "white") +
  geom_text(aes(label = round(usd_m)), size = 3) +
  scale_fill_gradient(low = "#f6efe6", high = "#5b1a2a", name = "log(1+USD m)") +
  labs(x = NULL, y = NULL,
       title = "Official humanitarian and recovery funding, 2014-2024 (USD million)",
       caption = "Source: UN OCHA Financial Tracking Service; author's calculations.")
ggsave(file.path(DIR$fig, "F1_heatmap_donor_recipient.png"), g1, width = 9, height = 5, dpi = 300)

g2 <- ggplot(panel[recipient == "SYR" & donor %in% c("QAT", "SAU", "ARE", "KWT", "TUR", "DEU")],
             aes(year, flow_off, colour = donor)) + geom_line(linewidth = 0.9) + geom_point() +
  geom_vline(xintercept = 2024.9, linetype = 2) +
  labs(x = NULL, y = "USD million", colour = NULL,
       title = "Official funding to Syria by donor, 2014-2025",
       caption = "Dashed line: fall of the Assad government (Dec 2024). Source: UN OCHA FTS.")
ggsave(file.path(DIR$fig, "F2_syria_by_donor.png"), g2, width = 9, height = 5, dpi = 300)

g3 <- ggplot(panel[year %in% EST_YEARS & !is.na(agree_l1)],
             aes(agree_l1, log1p(flow_off), colour = factor(gulf, labels = c("Other", "Gulf")))) +
  geom_point(alpha = 0.5) + geom_smooth(method = "lm", se = FALSE) +
  labs(x = "UNGA voting agreement with recipient (t-1)", y = "log(1 + official funding, USD m)",
       colour = NULL, title = "Political alignment and official funding, 2015-2024",
       caption = "Source: UN OCHA FTS; Bailey, Strezhnev & Voeten UNGA data.")
ggsave(file.path(DIR$fig, "F3_alignment_scatter.png"), g3, width = 8, height = 5, dpi = 300)

