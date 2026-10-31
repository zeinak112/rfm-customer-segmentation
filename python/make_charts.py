"""Generate the README charts from data/processed/*.csv (same palette as the Tableau theme)."""
from pathlib import Path
import pandas as pd, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, PercentFormatter

ROOT = Path(__file__).resolve().parents[1]
P, IMG = ROOT / "data" / "processed", ROOT / "images"
NAVY, INK, MUTED, GRID, BG = "#1B365D", "#2B3A4A", "#6B7A8C", "#E3E8EF", "#FFFFFF"
SEG = {"Champions": "#0B6E4F", "Loyal": "#2E86AB", "Potential Loyalists": "#8FBBD9",
       "New Customers": "#7B6FB0", "About to Sleep": "#E9C46A", "At Risk": "#F28C38",
       "Cant Lose Them": "#D1495B", "Hibernating": "#9AA5B1"}
LABEL = {"Cant Lose Them": "Can't Lose Them"}

plt.rcParams.update({"font.family": "DejaVu Sans", "axes.edgecolor": GRID, "axes.labelcolor": MUTED,
                     "xtick.color": MUTED, "ytick.color": MUTED, "axes.spines.top": False,
                     "axes.spines.right": False, "figure.facecolor": BG, "axes.facecolor": BG})

def title(ax, head, sub=None):
    ax.set_title(head, loc="left", fontsize=14, fontweight="bold", color=NAVY, pad=26 if sub else 12)
    if sub:
        ax.text(0, 1.03, sub, transform=ax.transAxes, fontsize=10, color=MUTED, va="bottom")

gbp = FuncFormatter(lambda v, _: f"£{v/1e6:.1f}M" if v >= 1e6 else f"£{v/1e3:.0f}K")

# 1 -------------------------------------------------- monthly revenue
m = pd.read_csv(P / "monthly_sales.csv")
fig, ax = plt.subplots(figsize=(10, 4.6))
colors = [("#B8C4D6" if s != "Full" else NAVY) for s in m.Month_Status]
for i, r in m.iterrows():
    if r.Month in ("2011-09", "2011-10", "2011-11"): colors[i] = "#0B6E4F"
bars = ax.bar(m.Month.str[2:], m.Revenue, color=colors, width=0.7)
bars[-1].set_hatch("//"); bars[-1].set_edgecolor("white")
q4 = m[m.Month.isin(["2011-09", "2011-10", "2011-11"])].Revenue.sum() / m[m.Month_Status == "Full"].Revenue.sum()
title(ax, f"Sep-Nov generate {q4:.0%} of full-month revenue",
      "Monthly revenue, Dec 2010 - Dec 2011 (Dec 2011 hatched = only 9 days of data)")
ax.yaxis.set_major_formatter(gbp); ax.grid(axis="y", color=GRID); ax.set_axisbelow(True)
ax.set_xlabel("Month (YY-MM)")
fig.tight_layout(); fig.savefig(IMG / "01_monthly_revenue.png", dpi=200); plt.close(fig)

# 2 -------------------------------------------------- pareto
p = pd.read_csv(P / "pareto.csv")
ps = pd.read_csv(P / "pareto_summary.csv") if (P / "pareto_summary.csv").exists() else None
top20 = p[p.Cum_Customers_Pct <= 20].Cum_Revenue_Pct.max()
fig, ax = plt.subplots(figsize=(7.5, 5))
ax.plot(p.Cum_Customers_Pct, p.Cum_Revenue_Pct, color=NAVY, lw=2.5)
ax.plot([0, 100], [0, 100], color=MUTED, ls="--", lw=1)
ax.fill_between(p.Cum_Customers_Pct, p.Cum_Revenue_Pct, p.Cum_Customers_Pct, color=NAVY, alpha=0.08)
ax.scatter([20], [top20], color="#D1495B", zorder=5, s=60)
ax.annotate(f"Top 20% of customers\n= {top20:.0f}% of revenue", (20, top20), (33, top20 - 22),
            fontsize=10.5, color=INK, fontweight="bold", arrowprops=dict(arrowstyle="-", color=MUTED))
title(ax, "Revenue is highly concentrated", "Cumulative revenue share vs. cumulative customer share")
ax.xaxis.set_major_formatter(PercentFormatter(100)); ax.yaxis.set_major_formatter(PercentFormatter(100))
ax.set_xlabel("Customers (ranked by spend)"); ax.set_ylabel("Cumulative revenue"); ax.grid(color=GRID); ax.set_axisbelow(True)
fig.tight_layout(); fig.savefig(IMG / "02_pareto.png", dpi=200); plt.close(fig)

# 3 -------------------------------------------------- segment value
s = pd.read_csv(P / "segment_summary.csv").sort_values("Revenue_Pct")
y = np.arange(len(s)); h = 0.38
fig, ax = plt.subplots(figsize=(10, 5.4))
ax.barh(y + h/2, s.Revenue_Pct, h, color=[SEG[x] for x in s.Segment], label="% of revenue")
ax.barh(y - h/2, s.Customers_Pct, h, color=[SEG[x] for x in s.Segment], alpha=0.35, label="% of customers")
for i, r in enumerate(s.itertuples()):
    ax.text(r.Revenue_Pct + 0.8, i + h/2, f"{r.Revenue_Pct:.1f}%", va="center", fontsize=9, color=INK, fontweight="bold")
    ax.text(r.Customers_Pct + 0.8, i - h/2, f"{r.Customers_Pct:.1f}%", va="center", fontsize=9, color=MUTED)
ax.set_yticks(y); ax.set_yticklabels([LABEL.get(x, x) for x in s.Segment], color=INK)
title(ax, "Champions are 23% of customers but 66% of revenue", "Solid bar = share of revenue, light bar = share of customers")
ax.xaxis.set_major_formatter(PercentFormatter(100)); ax.grid(axis="x", color=GRID); ax.set_axisbelow(True)
fig.tight_layout(); fig.savefig(IMG / "03_segment_value.png", dpi=200); plt.close(fig)

# 4 -------------------------------------------------- R x F heatmap
c = pd.read_csv(P / "customers_rfm.csv")
grid = c.pivot_table(index="R_Score", columns="F_Score", values="CustomerID", aggfunc="count", fill_value=0).sort_index(ascending=False)
rev = c.pivot_table(index="R_Score", columns="F_Score", values="Monetary", aggfunc="sum", fill_value=0).reindex(grid.index)
fig, ax = plt.subplots(figsize=(7.4, 5.2))
im = ax.imshow(grid.values, cmap=matplotlib.colors.LinearSegmentedColormap.from_list("n", ["#F3F6FA", "#8FBBD9", NAVY]))
for i in range(grid.shape[0]):
    for j in range(grid.shape[1]):
        v = grid.values[i, j]
        ax.text(j, i, f"{v:,}\n£{rev.values[i, j]/1e3:,.0f}K", ha="center", va="center", fontsize=8.5,
                color="white" if v > grid.values.max() * 0.55 else INK)
ax.set_xticks(range(5)); ax.set_xticklabels(grid.columns); ax.set_yticks(range(5)); ax.set_yticklabels(grid.index)
ax.set_xlabel("Frequency score (5 = most orders)"); ax.set_ylabel("Recency score (5 = most recent)")
for sp in ax.spines.values(): sp.set_visible(False)
title(ax, "Customers and revenue by Recency x Frequency", "Cell = customers (top) and revenue (bottom)")
fig.tight_layout(); fig.savefig(IMG / "04_rfm_heatmap.png", dpi=200); plt.close(fig)

# 5 -------------------------------------------------- cohort heatmap
co = pd.read_csv(P / "cohort_retention.csv")
pv = co.pivot(index="cohort_month", columns="month_offset", values="retention_pct")
pv = pv.iloc[:-1, 1:]                                    # drop Dec-11 cohort (no follow-up) and month 0
for cm in pv.index:                                      # hide cells that fall in the partial month (Dec 2011)
    y0, m0 = int(cm[:4]), int(cm[5:])
    for off in pv.columns:
        if (y0 * 12 + m0 - 1 + off) == (2011 * 12 + 11):
            pv.loc[cm, off] = np.nan
fig, ax = plt.subplots(figsize=(10, 5.6))
im = ax.imshow(pv.values, cmap=matplotlib.colors.LinearSegmentedColormap.from_list("t", ["#F3F6FA", "#7FC4B8", "#0B6E4F"]), vmin=0, vmax=40)
for i in range(pv.shape[0]):
    for j in range(pv.shape[1]):
        v = pv.values[i, j]
        if not np.isnan(v): ax.text(j, i, f"{v:.0f}%", ha="center", va="center", fontsize=8.5, color="white" if v > 28 else INK)
ax.set_xticks(range(pv.shape[1])); ax.set_xticklabels(pv.columns); ax.set_yticks(range(pv.shape[0])); ax.set_yticklabels(pv.index)
ax.set_xlabel("Months since first purchase"); ax.set_ylabel("Cohort (first-purchase month)")
for sp in ax.spines.values(): sp.set_visible(False)
title(ax, "Fewer than 1 in 4 new customers orders again the next month",
      "% of each cohort ordering again (Dec-2010 cohort includes older customers; partial Dec-2011 hidden)")
fig.tight_layout(); fig.savefig(IMG / "05_cohort_retention.png", dpi=200); plt.close(fig)

# 6 -------------------------------------------------- revenue at risk
r = s.set_index("Segment")
order = ["Champions", "Loyal", "Cant Lose Them", "At Risk"]
fig, ax = plt.subplots(figsize=(8.2, 4.4))
vals = [r.loc[k, "Revenue"] for k in order]
ax.bar([LABEL.get(k, k) for k in order], vals, color=[SEG[k] for k in order], width=0.6)
for i, v in enumerate(vals): ax.text(i, v + max(vals) * 0.015, f"£{v/1e3:,.0f}K", ha="center", fontsize=10, fontweight="bold", color=INK)
risk = r.loc[["Cant Lose Them", "At Risk"], "Revenue"].sum(); n = int(r.loc[["Cant Lose Them", "At Risk"], "Customers"].sum())
title(ax, f"{n} customers worth £{risk/1e3:,.0f}K are slipping away", "Historical revenue of the four most valuable segments")
ax.yaxis.set_major_formatter(gbp); ax.grid(axis="y", color=GRID); ax.set_axisbelow(True)
fig.tight_layout(); fig.savefig(IMG / "06_revenue_at_risk.png", dpi=200); plt.close(fig)
print("charts saved:", sorted(x.name for x in IMG.glob("*.png")))
