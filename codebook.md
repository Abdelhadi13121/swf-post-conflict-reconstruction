# Codebook

## `data/raw/fts_flows_raw_parsed.csv`

One row per FTS flow and usage year, for flows recorded against the eight recipients. Unfiltered.

| Variable | Description |
|---|---|
| `flow_id` | FTS flow identifier |
| `amount_usd` | Flow amount in current US dollars |
| `status` | `paid`, `commitment` or `pledge` |
| `boundary` | `incoming`, `internal` or `outgoing` relative to the recipient country |
| `on_boundary` | `single` or `shared` (flow split across several countries) |
| `flow_type` | `Standard`, `Carryover`, `Parked` or `Pass through` |
| `new_money` | TRUE if the flow is new money, not a pass-through of earlier funding |
| `date` | Date of the flow |
| `src_org`, `src_orgtype`, `src_loc` | Source organization, its type and its country |
| `dst_org`, `dst_loc` | Destination organization and location(s) |
| `n_dst_loc` | Number of destination locations |
| `recipient` | ISO3 code of the recipient queried (SYR, IRQ, LBY, YEM, PSE, AFG, SDN, SOM) |
| `year` | Usage year queried (2014–2025) |

## `data/raw/fts_completeness_check.csv`

| Variable | Description |
|---|---|
| `recipient`, `year` | Recipient-year |
| `n_pages` | API pages downloaded (200 flows per page) |
| `meta_count` | Number of flows reported by FTS |
| `n_parsed` | Number of flows parsed |
| `count_ratio` | `n_parsed / meta_count` (equals 1 in all 96 recipient-years) |
| `fts_incoming_usd`, `parsed_incoming_usd`, `usd_ratio` | FTS-reported vs parsed incoming funding |

## `data/raw/unga_agreement_subset.csv`

| Variable | Description |
|---|---|
| `ccode1`, `ccode2` | Correlates of War country codes |
| `year` | UN General Assembly session year |
| `agree` | Share of roll-call votes on which the two countries agree |
| `IdealPointDistance` | Absolute distance between the two countries' ideal points |

## `data/processed/panel_donor_recipient_year.csv`

Balanced panel: 9 donors × 8 recipients × 12 years (2014–2025) = 864 rows. Flows in USD million.

| Variable | Description |
|---|---|
| `donor` | QAT, SAU, ARE, KWT, TUR, NOR, DEU, GBR, USA |
| `recipient`, `year` | As above |
| `flow_off` | Official funding: governments and public agencies (main outcome) |
| `flow_all` | All funding from the donor country, including charities |
| `flow_off_sgl` | Official funding to a single destination country only |
| `flow_paid` | Official funding with status `paid` |
| `agree_l1` | UNGA voting agreement, lagged one year |
| `ipd_l1` | Ideal-point distance, lagged one year |
| `gulf` | 1 for QAT, SAU, ARE, KWT |
| `arab_d`, `arab_r` | Arab League membership of donor and recipient |
| `log_dist` | Log great-circle distance between capitals (km) |
| `arab_common` | Both in the Arab League; 0 for Syria during its suspension (2011–2022) |
| `qatar` | 1 for Qatar |
| `pair` | Donor–recipient identifier (clustering unit) |

## Cleaning rules (`code/02_build_panel.R`)

Flows are kept if they are incoming, paid or committed (pledges dropped), standard (carry-over, parked and pass-through dropped), new money and positive. A flow recorded in several usage years is counted once, in its first year. Donors are identified from the FTS source location, with the government name as a fallback. Every step is logged in `output/logs/validation_log.txt`.

## `data/deal_ledger/swf_deal_ledger.csv`

One row per documented sovereign or state-linked deal: date, recipient, home state, vehicle, vehicle type, link to the sovereign wealth fund, sector, announced value (USD million), instrument, status and two sources. Values are announced amounts, not disbursements.
