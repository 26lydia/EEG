"""Selection fitted only on the provided training subjects."""
from dataclasses import asdict, dataclass

import numpy as np
import pandas as pd
from scipy.stats import pearsonr
from sklearn.feature_selection import mutual_info_regression
from sklearn.linear_model import ElasticNet
from sklearn.preprocessing import StandardScaler


@dataclass
class SelectionConfig:
    method: str = "pearson"
    top_k: int = 15
    correlation_limit: float = 0.8
    min_observed_fraction: float = 0.5
    alpha: float = 0.05
    l1_ratio: float = 0.5
    bootstrap_runs: int = 30
    stability: float = 0.6
    seed: int = 42

    def validate(self):
        if self.method not in {"pearson", "mi", "elasticnet", "xgboost", "none"}:
            raise ValueError("Unknown selection method.")
        if self.top_k < 1 or self.bootstrap_runs < 1 or self.alpha <= 0:
            raise ValueError("top_k, bootstrap_runs and alpha must be positive.")
        if not (0 < self.correlation_limit <= 1 and 0 < self.min_observed_fraction <= 1):
            raise ValueError("Correlation limit and observed fraction must be in (0,1].")
        if not (0 <= self.stability <= 1 and 0 <= self.l1_ratio <= 1):
            raise ValueError("stability and l1_ratio must be in [0,1].")


def fdr_bh(p):
    q = np.full(len(p), np.nan)
    valid = np.flatnonzero(np.isfinite(p))
    order = valid[np.argsort(np.asarray(p)[valid])]
    if len(order):
        raw = np.asarray(p)[order] * len(order) / np.arange(1, len(order) + 1)
        q[order] = np.minimum(1, np.minimum.accumulate(raw[::-1])[::-1])
    return q


class FeatureSelector:
    def __init__(self, config=None):
        self.config = config or SelectionConfig()

    def fit(self, X, y, groups=None):
        c = self.config
        c.validate()
        X = X.replace([np.inf, -np.inf], np.nan)
        y = np.asarray(y, dtype=float)
        if len(y) != len(X) or not np.isfinite(y).all() or np.unique(y).size < 2:
            raise ValueError("Training targets must be finite, aligned and nonconstant.")
        if len(X) < 3:
            raise ValueError("At least three training rows are required.")
        # All thresholds, fill values, scores and redundancy checks use only X.
        observed = X.notna().sum()
        varying = X.nunique(dropna=True).gt(1)
        usable = (observed >= max(3, int(np.ceil(len(X) * c.min_observed_fraction)))) & varying
        names = X.columns[usable].tolist()
        if not names:
            raise ValueError("No usable training features (missing, constant or too sparsely observed).")
        raw = X[names]
        filled = raw.fillna(raw.median())
        scores = np.zeros(len(names))
        pvalues = np.full(len(names), np.nan)
        correlations = np.full(len(names), np.nan)
        counts = observed.loc[names].to_numpy()
        stability = np.full(len(names), np.nan)
        if c.method == "pearson":
            for j, name in enumerate(names):
                valid = raw[name].notna().to_numpy()
                if np.unique(y[valid]).size > 1:
                    correlations[j], pvalues[j] = pearsonr(raw.loc[valid, name], y[valid])
                    scores[j] = abs(correlations[j])
        elif c.method == "mi":
            scores = mutual_info_regression(filled, y, random_state=c.seed,
                                           n_neighbors=min(3, len(X) - 1))
        elif c.method in {"elasticnet", "xgboost"}:
            if groups is None:
                raise ValueError("Stability selection requires subject groups.")
            groups = np.asarray(groups)
            if len(groups) != len(X) or len(np.unique(groups)) < 3:
                raise ValueError("Stability selection requires at least three training subjects.")
            rng = np.random.default_rng(c.seed)
            unique = np.unique(groups)
            weights = []
            appearances = []
            for run in range(c.bootstrap_runs):
                # Cluster bootstrap keeps all rows for each sampled subject.
                drawn = rng.choice(unique, size=len(unique), replace=True)
                idx = np.concatenate([np.flatnonzero(groups == g) for g in drawn])
                bx = raw.iloc[idx]
                bx = bx.fillna(bx.median()).fillna(0)
                by = y[idx]
                if np.unique(by).size < 2:
                    continue
                if c.method == "elasticnet":
                    scaled = StandardScaler().fit_transform(bx)
                    estimator = ElasticNet(alpha=c.alpha, l1_ratio=c.l1_ratio,
                                           max_iter=20000, random_state=c.seed + run)
                    estimator.fit(scaled, by)
                    w = abs(estimator.coef_)
                    active = w > 1e-10
                else:
                    from xgboost import XGBRegressor
                    import shap
                    estimator = XGBRegressor(n_estimators=100, max_depth=2,
                                             learning_rate=0.05, subsample=0.8,
                                             colsample_bytree=0.8, n_jobs=1,
                                             random_state=c.seed + run)
                    estimator.fit(bx, by)
                    # Explain training subjects only, never validation targets/rows.
                    explanation = shap.TreeExplainer(estimator)
                    values = explanation.shap_values(bx.iloc[:min(200, len(bx))])
                    w = np.abs(values).mean(axis=0)
                    active = np.zeros(len(names), dtype=bool)
                    order = np.argsort(-w, kind="stable")[:c.top_k]
                    active[order] = w[order] > 0
                weights.append(w)
                appearances.append(active)
            if not weights:
                raise ValueError("No bootstrap with varying targets; need more subjects.")
            scores = np.mean(weights, axis=0)
            stability = np.mean(appearances, axis=0)
        else:
            scores[:] = 1
        self.ranking_ = pd.DataFrame({
            "Feature": names, "Score": scores, "PearsonR": correlations,
            "PValue": pvalues, "FDR_QValue": fdr_bh(pvalues),
            "ObservedRows": counts, "AppearanceRatio": stability,
        }).sort_values(["Score", "Feature"], ascending=[False, True])
        selected, decisions = [], []
        for row in self.ranking_.itertuples(index=False):
            reason = "selected"
            if c.method in {"elasticnet", "xgboost"} and row.AppearanceRatio < c.stability:
                reason = "below_stability_threshold"
            elif row.Score <= 0 or not np.isfinite(row.Score):
                reason = "zero_or_missing_score"
            elif len(selected) >= c.top_k and c.method != "none":
                reason = "outside_top_k"
            elif c.method != "none" and selected:
                # Compare against retained features, including negative redundancy.
                r = filled[selected].corrwith(filled[row.Feature]).abs()
                if r.ge(c.correlation_limit).any():
                    reason = "redundant_with_retained_feature"
            if reason == "selected":
                selected.append(row.Feature)
            decisions.append(reason)
        self.ranking_["Decision"] = decisions
        self.selected_ = selected
        self.dropped_ = pd.DataFrame({"Feature": X.columns[~usable],
                                      "Reason": "constant_or_insufficient_observations"})
        if not selected:
            raise ValueError("No features selected. Adjust thresholds using training data only.")
        return self

    def transform(self, X):
        return X[self.selected_].replace([np.inf, -np.inf], np.nan)

    def config_dict(self):
        return asdict(self.config)
