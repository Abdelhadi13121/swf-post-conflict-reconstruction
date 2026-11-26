# =============================================================================
# 05_paper_figures.R  -  Figures 1-3 of the paper
# Input : data/processed/panel_donor_recipient_year.csv, output/tables/T9_syria_2025_event.csv
# Output: output/figures/Figure1_portfolio_shares.png
#         output/figures/Figure2_syria_funding.png
#         output/figures/Figure3_event_placebos.png
# =============================================================================
if (!exists("panel")) panel <- fread(file.path(DIR$proc, "panel_donor_recipient_year.csv"))
MAR <- "#5b1a2a"; GOLD <- "#b8893b"; GREY <- "#8a8a8a"
theme_paper <- theme_minimal(base_size = 10, base_family = "serif") +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10))
dn <- c(QAT = "Qatar", SAU = "Saudi Arabia", ARE = "UAE", KWT = "Kuwait", TUR = "Turkiye",
        NOR = "Norway", DEU = "Germany", GBR = "United Kingdom", USA = "United States")
rn <- c(PSE = "Palestine", SYR = "Syria", YEM = "Yemen", IRQ = "Iraq", LBY = "Libya",
        SDN = "Sudan", SOM = "Somalia", AFG = "Afghanistan")

## Figure 1: portfolio shares, 2014-2024 ------------------------------------------
sh <- panel[year %in% 2014:2024, .(usd = sum(flow_off)), by = .(donor, recipient)][
  , share := 100 * usd / sum(usd), by = donor]
sh[, `:=`(donor = factor(dn[donor], levels = rev(dn)), recipient = factor(rn[recipient], levels = rn))]
f1 <- ggplot(sh, aes(recipient, donor, fill = share)) + geom_tile(colour = "white") +
  geom_text(aes(label = round(share), colour = share > 45), size = 2.8, family = "serif") +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = "white"), guide = "none") +
  scale_fill_gradientn(colours = c("#f7f1e8", GOLD, MAR), limits = c(0, 80), oob = scales::squish,
                       name = "% of donor\nportfolio") +
  geom_hline(yintercept = 4.5, colour = "white", linewidth = 1.5) +
  labs(x = NULL, y = NULL) + theme_paper +
  theme(axis.text.x = element_text(angle = 20, hjust = 1), panel.grid = element_blank())
ggsave(file.path(DIR$fig, "Figure1_portfolio_shares.png"), f1, width = 8, height = 4.2, dpi = 300)

## Figure 2: official funding to Syria -------------------------------------------
s <- panel[recipient == "SYR"]
grp <- function(d) fcase(d == "QAT", "Qatar", d == "SAU", "Saudi Arabia", d == "TUR", "Turkiye",
                         d %in% c("ARE", "KWT"), "UAE + Kuwait",
                         default = "Western donors (US, DE, UK, NO)")
s[, group := factor(grp(donor), levels = c("Western donors (US, DE, UK, NO)", "UAE + Kuwait",
                                           "Turkiye", "Saudi Arabia", "Qatar"))]
a <- s[, .(usd = sum(flow_off)), by = .(year, group)]
f2a <- ggplot(a, aes(factor(year), usd, fill = group)) + geom_col(width = 0.75) +
  scale_fill_manual(values = c("#c9c9c9", "#e8d9bf", "#d9b77a", GOLD, MAR), name = NULL) +
  labs(x = NULL, y = "USD million", title = "(a) Official funding to Syria, nine donors") +
  theme_paper + theme(axis.text.x = element_text(angle = 90, vjust = 0.5),
                      legend.position = c(0.25, 0.85), legend.key.size = unit(3, "mm"))
b <- s[, .(gulf = sum(flow_off[donor %in% c("QAT", "SAU", "ARE", "KWT", "TUR")]),
           qat = sum(flow_off[donor == "QAT"]), tot = sum(flow_off)), by = year]
b <- rbind(b[, .(year, share = 100 * gulf / tot, who = "Gulf states + Turkiye")],
           b[, .(year, share = 100 * qat / tot, who = "Qatar")])
f2b <- ggplot(b, aes(year, share, colour = who)) + geom_line(linewidth = 0.9) + geom_point(size = 1.4) +
  geom_vline(xintercept = 2024.95, linetype = 2, colour = GREY) +
  scale_colour_manual(values = c(GOLD, MAR), name = NULL) + ylim(0, 100) +
  labs(x = NULL, y = "% of nine-donor total", title = "(b) Shares") + theme_paper +
  theme(legend.position = c(0.35, 0.6))
png(file.path(DIR$fig, "Figure2_syria_funding.png"), width = 10, height = 3.8, units = "in", res = 300)
grid::grid.newpage(); grid::pushViewport(grid::viewport(layout = grid::grid.layout(1, 5)))
print(f2a, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1:3))
print(f2b, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 4:5))
invisible(dev.off())

## Figure 3: event estimate and placebos -------------------------------------------
ev <- fread(file.path(DIR$tab, "T9_syria_2025_event.csv"))[outcome == "flow_off"]
ev <- ev[!grepl("\\+", treated) & abs(b) < 10]        # single donors; UAE not identified
ev[, kind := fifelse(treated == "QAT" & recipient == "SYR", "own",
             fifelse(treated == "QAT", "rec", "don"))]
ev[, lab := paste0(dn[treated], " x ", rn[recipient], ", ", year)]
ev[, ord := fcase(kind == "own", year - 2030, kind == "don", 0, default = 1)]
setorder(ev, ord); ev[, lab := factor(lab, levels = rev(lab))]
f3 <- ggplot(ev, aes(b, lab, colour = kind)) + geom_vline(xintercept = 0, linewidth = 0.3) +
  geom_errorbar(aes(xmin = b - 1.96 * se, xmax = b + 1.96 * se), width = 0, orientation = "y") + geom_point(size = 2) +
  scale_colour_manual(values = c(own = MAR, don = GREY, rec = GOLD), guide = "none") +
  labs(x = "PPML coefficient (95% CI, clustered by pair)", y = NULL) + theme_paper
ggsave(file.path(DIR$fig, "Figure3_event_placebos.png"), f3, width = 7, height = 5.2, dpi = 300)
logf("Paper figures written to output/figures/")
