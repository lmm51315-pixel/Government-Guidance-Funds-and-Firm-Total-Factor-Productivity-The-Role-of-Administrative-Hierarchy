#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DML-IV Python脚本（含第一阶段诊断 + 敏感性检验）
========================================================
本版更新：
1. 保留 DML-IV 的两种实现：
   A. pliv_resid_2sls
   B. optimal_iv（默认，更贴近 orthogonal score / optimal instrument）
2. 增加第一阶段诊断输出：
   - 导出 linearmodels 的 first_stage.diagnostics
   - 汇总最小 first-stage F / 最小 partial R²
3. 最终只汇报三项：
   - GGF
   - GGF×高层级
   - 高层级总效应 = GGF + GGF×高层级
4. 保留超参数敏感性检验
"""

import warnings
warnings.filterwarnings("ignore")

from pathlib import Path
import json
import numpy as np
import pandas as pd

from scipy import stats
from sklearn.ensemble import RandomForestRegressor
from linearmodels.iv import IV2SLS


BASE_DIR = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
DATA_PATH = Path("/Users/lmm/Documents/Replication_Package_副本/data/cleandata.xlsx")
OUT_DIR = Path("/Users/lmm/Documents/Replication_Package_副本/out")
OUT_DIR.mkdir(parents=True, exist_ok=True)

RANDOM_SEED = 12345
N_SPLITS = 5
N_REPS = 1


# 可选: "pliv_resid_2sls" 或 "optimal_iv"
ESTIMATOR_MODE = "optimal_iv"

Y1 = "TFP_LP"
Y2 = "TFP_OP"
X = "GGF"
ID = "id"
YEAR = "year"
TYPE1 = "level"

CTRLS_FIRM = [
    "lev", "roa", "cash", "growth",
    "Big4", "两职合一", "Independent", "HHI", "soe"
]

ZBASE = [
    "L1_fund_density2", "L1_fund_density1",
    "L2_fund_density2", "L2_fund_density1"
]

RF_CONFIGS = {
    "baseline": {
        "n_estimators": 300,
        "max_depth": None,
        "min_samples_leaf": 5,
        "max_features": "sqrt",
    },
    "flexible": {
        "n_estimators": 500,
        "max_depth": None,
        "min_samples_leaf": 1,
        "max_features": "sqrt",
    },
    "Moderate": {
        "n_estimators": 400,
        "max_depth": 8,
        "min_samples_leaf": 8,
        "max_features": 0.7,
    },
    "shallow": {
        "n_estimators": 300,
        "max_depth": 6,
        "min_samples_leaf": 10,
        "max_features": 0.7,
    },
    "conservative": {
        "n_estimators": 200,
        "max_depth": 4,
        "min_samples_leaf": 15,
        "max_features": 0.5,
    },
}


def make_group_folds(groups, n_splits=5, seed=12345, rep=0):
    groups = pd.Series(groups)
    uniq = groups.drop_duplicates().to_numpy().copy()
    rng = np.random.RandomState(seed + rep)
    rng.shuffle(uniq)
    fold_map = {g: i % n_splits for i, g in enumerate(uniq)}
    return groups.map(fold_map).to_numpy()


def within_transform(df, group_col, cols):
    out = df.copy()
    gmean = out.groupby(group_col)[cols].transform("mean")
    for c in cols:
        out[f"{c}_w"] = out[c] - gmean[c]
    return out


def build_rf(params, seed):
    return RandomForestRegressor(
        n_estimators=params["n_estimators"],
        max_depth=params["max_depth"],
        min_samples_leaf=params["min_samples_leaf"],
        max_features=params["max_features"],
        random_state=seed,
        n_jobs=-1,
    )


def linear_combo_test(res, terms, weights, alpha=0.05):
    params = res.params
    cov = res.cov

    w = np.zeros(len(params))
    pos = {name: i for i, name in enumerate(params.index)}

    for t, wt in zip(terms, weights):
        if t not in pos:
            raise KeyError(f"{t} 不在参数列表中，可选项：{list(params.index)}")
        w[pos[t]] = wt

    est = float(w @ params.values)
    var = float(w @ cov.values @ w)
    se = np.sqrt(var) if var >= 0 else np.nan

    z = est / se if se > 0 else np.nan
    p = 2 * (1 - stats.norm.cdf(abs(z))) if np.isfinite(z) else np.nan
    zcrit = stats.norm.ppf(0.975)
    ci_low = est - zcrit * se if np.isfinite(se) else np.nan
    ci_high = est + zcrit * se if np.isfinite(se) else np.nan

    return {
        "estimate": est,
        "std_error": se,
        "z_stat": z,
        "p_value": p,
        "ci_low": ci_low,
        "ci_high": ci_high
    }


def print_main_effects(res, title):
    tests = {
        "GGF": (["d_w"], [1.0]),
        "GGF×高层级": (["d_int_w"], [1.0]),
        "高层级总效应": (["d_w", "d_int_w"], [1.0, 1.0]),
    }

    print("\n" + "=" * 72)
    print(title)
    print("=" * 72)

    for name, (terms, weights) in tests.items():
        out = linear_combo_test(res, terms, weights)
        print(f"\n{name}")
        print(f"Estimate   = {out['estimate']:.6f}")
        print(f"Std.Error  = {out['std_error']:.6f}")
        print(f"z-stat     = {out['z_stat']:.6f}")
        print(f"P>|z|      = {out['p_value']:.6f}")
        print(f"95% CI     = [{out['ci_low']:.6f}, {out['ci_high']:.6f}]")


def prepare_data(df):
    df = df.copy()

    df["year_id"] = pd.to_datetime(df[YEAR]).dt.year
    df = df[df["year_id"] > 2012].copy()

    needed = [Y1, Y2, X, TYPE1, ID, YEAR] + CTRLS_FIRM + ZBASE
    df = df.dropna(subset=needed).copy()

    uniq_level = set(pd.Series(df[TYPE1]).dropna().unique().tolist())
    if not uniq_level.issubset({0, 1}):
        raise ValueError(f"{TYPE1} 必须是0/1变量，当前取值为: {sorted(uniq_level)}")

    df["firm_id"] = df[ID]
    df["y1"] = df[Y1]
    df["y2"] = df[Y2]
    df["d"] = df[X]
    df["lvl"] = df[TYPE1].astype(int)

    ctrl_map = {
        "c1": "lev",
        "c2": "roa",
        "c3": "cash",
        "c4": "growth",
        "c5": "Big4",
        "c6": "两职合一",
        "c7": "Independent",
        "c8": "HHI",
        "c9": "soe",
    }
    for k, v in ctrl_map.items():
        df[k] = df[v]

    df["d_int"] = df["d"] * df["lvl"]

    z_map = {
        "z1": "L1_fund_density2",
        "z2": "L1_fund_density1",
        "z3": "L2_fund_density2",
        "z4": "L2_fund_density1",
    }
    for k, v in z_map.items():
        df[k] = df[v]
    for z in ["z1", "z2", "z3", "z4"]:
        df[f"{z}_int"] = df[z] * df["lvl"]

    to_within = [
        "y1", "y2", "d", "d_int",
        "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9",
        "z1", "z2", "z3", "z4", "z1_int", "z2_int", "z3_int", "z4_int"
    ]
    df = within_transform(df, "firm_id", to_within)

    year_dummies = pd.get_dummies(df["year_id"], prefix="yr", drop_first=True, dtype=float)
    df = pd.concat([df, year_dummies], axis=1)

    year_fe = year_dummies.columns.tolist()
    xw = ["c1_w", "c2_w", "c3_w", "c4_w", "c5_w", "c6_w", "c7_w", "c8_w", "c9_w"] + year_fe
    dw = ["d_w", "d_int_w"]
    zw = [
        "z1_w", "z2_w", "z3_w", "z4_w",
        "z1_int_w", "z2_int_w", "z3_int_w", "z4_int_w"
    ]
    xz = xw + zw

    return df, xw, dw, zw, xz


def crossfit_pliv_resid_2sls(df, y_col, x_cols, d_cols, z_cols, group_col, rf_params,
                             n_splits=5, n_reps=5, seed=12345):
    n = len(df)
    X = df[x_cols]
    groups = df[group_col].to_numpy()

    y_hat_all = np.zeros((n, n_reps))
    d_hat_all = {d: np.zeros((n, n_reps)) for d in d_cols}
    z_hat_all = {z: np.zeros((n, n_reps)) for z in z_cols}

    for rep in range(n_reps):
        fold_id = make_group_folds(groups, n_splits=n_splits, seed=seed, rep=rep)

        y_pred = np.full(n, np.nan)
        d_pred = {d: np.full(n, np.nan) for d in d_cols}
        z_pred = {z: np.full(n, np.nan) for z in z_cols}

        for fold in range(n_splits):
            tr = np.where(fold_id != fold)[0]
            te = np.where(fold_id == fold)[0]

            X_tr = X.iloc[tr]
            X_te = X.iloc[te]

            m_y = build_rf(rf_params, seed + rep * 100 + fold)
            m_y.fit(X_tr, df[y_col].iloc[tr])
            y_pred[te] = m_y.predict(X_te)

            for d in d_cols:
                m_d = build_rf(rf_params, seed + rep * 100 + fold + 1000)
                m_d.fit(X_tr, df[d].iloc[tr])
                d_pred[d][te] = m_d.predict(X_te)

            for z in z_cols:
                m_z = build_rf(rf_params, seed + rep * 100 + fold + 2000)
                m_z.fit(X_tr, df[z].iloc[tr])
                z_pred[z][te] = m_z.predict(X_te)

        y_hat_all[:, rep] = y_pred
        for d in d_cols:
            d_hat_all[d][:, rep] = d_pred[d]
        for z in z_cols:
            z_hat_all[z][:, rep] = z_pred[z]

    y_hat = y_hat_all.mean(axis=1)
    d_hat = pd.DataFrame({d: arr.mean(axis=1) for d, arr in d_hat_all.items()}, index=df.index)
    z_hat = pd.DataFrame({z: arr.mean(axis=1) for z, arr in z_hat_all.items()}, index=df.index)
    return y_hat, d_hat, z_hat


def crossfit_optimal_iv(df, y_col, x_cols, d_cols, xz_cols, group_col, rf_params,
                        n_splits=5, n_reps=5, seed=12345):
    n = len(df)
    X = df[x_cols]
    XZ = df[xz_cols]
    groups = df[group_col].to_numpy()

    y_hat_all = np.zeros((n, n_reps))
    r_hat_all = {d: np.zeros((n, n_reps)) for d in d_cols}
    p_hat_all = {d: np.zeros((n, n_reps)) for d in d_cols}

    for rep in range(n_reps):
        fold_id = make_group_folds(groups, n_splits=n_splits, seed=seed, rep=rep)

        y_pred = np.full(n, np.nan)
        r_pred = {d: np.full(n, np.nan) for d in d_cols}
        p_pred = {d: np.full(n, np.nan) for d in d_cols}

        for fold in range(n_splits):
            tr = np.where(fold_id != fold)[0]
            te = np.where(fold_id == fold)[0]

            X_tr = X.iloc[tr]
            X_te = X.iloc[te]
            XZ_tr = XZ.iloc[tr]
            XZ_te = XZ.iloc[te]

            m_y = build_rf(rf_params, seed + rep * 100 + fold)
            m_y.fit(X_tr, df[y_col].iloc[tr])
            y_pred[te] = m_y.predict(X_te)

            for d in d_cols:
                m_r = build_rf(rf_params, seed + rep * 100 + fold + 1000)
                m_r.fit(X_tr, df[d].iloc[tr])
                r_pred[d][te] = m_r.predict(X_te)

                m_p = build_rf(rf_params, seed + rep * 100 + fold + 2000)
                m_p.fit(XZ_tr, df[d].iloc[tr])
                p_pred[d][te] = m_p.predict(XZ_te)

        y_hat_all[:, rep] = y_pred
        for d in d_cols:
            r_hat_all[d][:, rep] = r_pred[d]
            p_hat_all[d][:, rep] = p_pred[d]

    y_hat = y_hat_all.mean(axis=1)
    r_hat = pd.DataFrame({d: arr.mean(axis=1) for d, arr in r_hat_all.items()}, index=df.index)
    p_hat = pd.DataFrame({d: arr.mean(axis=1) for d, arr in p_hat_all.items()}, index=df.index)
    return y_hat, r_hat, p_hat


def estimate_pliv_resid_2sls(df, y_col, x_cols, d_cols, z_cols, group_col, rf_params):
    y_hat, d_hat, z_hat = crossfit_pliv_resid_2sls(
        df=df, y_col=y_col, x_cols=x_cols, d_cols=d_cols, z_cols=z_cols,
        group_col=group_col, rf_params=rf_params,
        n_splits=N_SPLITS, n_reps=N_REPS, seed=RANDOM_SEED,
    )

    y_tilde = df[y_col] - y_hat
    d_tilde = pd.DataFrame({d: df[d] - d_hat[d] for d in d_cols}, index=df.index)
    z_tilde = pd.DataFrame({z: df[z] - z_hat[z] for z in z_cols}, index=df.index)
    exog = pd.DataFrame({"const": np.ones(len(df))}, index=df.index)

    model = IV2SLS(
        dependent=y_tilde,
        exog=exog,
        endog=d_tilde,
        instruments=z_tilde
    ).fit(cov_type="clustered", clusters=df[group_col])

    return {"model": model}


def estimate_optimal_iv(df, y_col, x_cols, d_cols, xz_cols, group_col, rf_params):
    y_hat, r_hat, p_hat = crossfit_optimal_iv(
        df=df, y_col=y_col, x_cols=x_cols, d_cols=d_cols, xz_cols=xz_cols,
        group_col=group_col, rf_params=rf_params,
        n_splits=N_SPLITS, n_reps=N_REPS, seed=RANDOM_SEED,
    )

    y_tilde = df[y_col] - y_hat
    d_tilde = pd.DataFrame({d: df[d] - r_hat[d] for d in d_cols}, index=df.index)
    w_hat = pd.DataFrame({d: p_hat[d] - r_hat[d] for d in d_cols}, index=df.index)
    exog = pd.DataFrame({"const": np.ones(len(df))}, index=df.index)

    model = IV2SLS(
        dependent=y_tilde,
        exog=exog,
        endog=d_tilde,
        instruments=w_hat
    ).fit(cov_type="clustered", clusters=df[group_col])

    return {"model": model}


def extract_main_result_rows(model, outcome_name, estimator_mode, config_name):
    rows = []

    rows.append({
        "outcome": outcome_name,
        "estimator_mode": estimator_mode,
        "config": config_name,
        "term": "GGF",
        "coef": model.params.get("d_w", np.nan),
        "se": model.std_errors.get("d_w", np.nan),
        "p_value": model.pvalues.get("d_w", np.nan),
        "nobs": model.nobs,
    })

    rows.append({
        "outcome": outcome_name,
        "estimator_mode": estimator_mode,
        "config": config_name,
        "term": "GGF×高层级",
        "coef": model.params.get("d_int_w", np.nan),
        "se": model.std_errors.get("d_int_w", np.nan),
        "p_value": model.pvalues.get("d_int_w", np.nan),
        "nobs": model.nobs,
    })

    high_effect = linear_combo_test(model, ["d_w", "d_int_w"], [1.0, 1.0])
    rows.append({
        "outcome": outcome_name,
        "estimator_mode": estimator_mode,
        "config": config_name,
        "term": "高层级总效应",
        "coef": high_effect["estimate"],
        "se": high_effect["std_error"],
        "p_value": high_effect["p_value"],
        "nobs": model.nobs,
    })

    return rows


def extract_first_stage_rows(model, outcome_name, estimator_mode, config_name):
    try:
        fs = model.first_stage
        diag = fs.diagnostics.copy().reset_index().rename(columns={"index": "endog_var"})
    except Exception:
        return pd.DataFrame()

    rename_map = {
        "rsquared": "rsquared",
        "partial.rsquared": "partial_rsquared",
        "shea.rsquared": "shea_rsquared",
        "f.stat": "f_stat",
        "f.pval": "f_pvalue",
        "f.dist": "f_dist",
    }
    diag = diag.rename(columns=rename_map)

    diag["outcome"] = outcome_name
    diag["estimator_mode"] = estimator_mode
    diag["config"] = config_name

    keep_cols = [c for c in [
        "outcome", "estimator_mode", "config", "endog_var",
        "rsquared", "partial_rsquared", "shea_rsquared",
        "f_stat", "f_pvalue", "f_dist"
    ] if c in diag.columns]

    return diag[keep_cols]


def summarize_sensitivity(res_df):
    return (
        res_df.groupby(["outcome", "estimator_mode", "term"])
        .agg(
            n_configs=("config", "nunique"),
            coef_mean=("coef", "mean"),
            coef_std=("coef", "std"),
            coef_min=("coef", "min"),
            coef_max=("coef", "max"),
            share_p_lt_10=("p_value", lambda x: np.mean(x < 0.10)),
            share_p_lt_05=("p_value", lambda x: np.mean(x < 0.05)),
            share_p_lt_01=("p_value", lambda x: np.mean(x < 0.01)),
        )
        .reset_index()
    )


def summarize_first_stage(fs_df):
    if fs_df.empty:
        return pd.DataFrame()

    out = (
        fs_df.groupby(["outcome", "estimator_mode", "config"])
        .agg(
            min_f_stat=("f_stat", "min"),
            mean_f_stat=("f_stat", "mean"),
            min_partial_rsquared=("partial_rsquared", "min"),
            mean_partial_rsquared=("partial_rsquared", "mean"),
        )
        .reset_index()
    )
    out["flag_min_f_lt_10"] = (out["min_f_stat"] < 10).astype(int)
    return out


def run_one_spec(df, outcome_name, y_col, x_cols, d_cols, z_cols, xz_cols,
                 rf_name, rf_params, estimator_mode):
    if estimator_mode == "pliv_resid_2sls":
        out = estimate_pliv_resid_2sls(
            df=df, y_col=y_col, x_cols=x_cols, d_cols=d_cols, z_cols=z_cols,
            group_col="firm_id", rf_params=rf_params
        )
    elif estimator_mode == "optimal_iv":
        out = estimate_optimal_iv(
            df=df, y_col=y_col, x_cols=x_cols, d_cols=d_cols, xz_cols=xz_cols,
            group_col="firm_id", rf_params=rf_params
        )
    else:
        raise ValueError("estimator_mode 必须是 'pliv_resid_2sls' 或 'optimal_iv'")

    print(f"\n\n########## {outcome_name} | {estimator_mode} | {rf_name} ##########")
    print(out["model"].summary)
    print_main_effects(out["model"], f"{outcome_name} | {estimator_mode} | {rf_name}")

    if rf_name == "baseline":
        try:
            print("\n--- First Stage Diagnostics ---")
            print(out["model"].first_stage)
        except Exception:
            pass

    rows = extract_main_result_rows(out["model"], outcome_name, estimator_mode, rf_name)
    fs_df = extract_first_stage_rows(out["model"], outcome_name, estimator_mode, rf_name)

    return rows, fs_df


def main():
    print(f"Reading data from: {DATA_PATH}")
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"未找到数据文件：{DATA_PATH}")

    df = pd.read_excel(DATA_PATH)
    df, XW, DW, ZW, XZ = prepare_data(df)

    print(f"样本量 = {len(df)}")
    print(f"年份虚拟变量个数 = {len([c for c in XW if c.startswith('yr_')])}")
    print(f"估计模式 = {ESTIMATOR_MODE}")
    print(f"超参数组数 = {len(RF_CONFIGS)}")

    all_rows = []
    all_fs = []

    for rf_name, rf_params in RF_CONFIGS.items():
        rows_lp, fs_lp = run_one_spec(
            df=df, outcome_name="TFP_LP", y_col="y1_w",
            x_cols=XW, d_cols=DW, z_cols=ZW, xz_cols=XZ,
            rf_name=rf_name, rf_params=rf_params,
            estimator_mode=ESTIMATOR_MODE
        )
        all_rows.extend(rows_lp)
        if not fs_lp.empty:
            all_fs.append(fs_lp)

        rows_op, fs_op = run_one_spec(
            df=df, outcome_name="TFP_OP", y_col="y2_w",
            x_cols=XW, d_cols=DW, z_cols=ZW, xz_cols=XZ,
            rf_name=rf_name, rf_params=rf_params,
            estimator_mode=ESTIMATOR_MODE
        )
        all_rows.extend(rows_op)
        if not fs_op.empty:
            all_fs.append(fs_op)

    results_df = pd.DataFrame(all_rows)
    first_stage_df = pd.concat(all_fs, axis=0, ignore_index=True) if all_fs else pd.DataFrame()
    sensitivity_df = summarize_sensitivity(results_df)
    first_stage_summary_df = summarize_first_stage(first_stage_df)

    out_path = OUT_DIR / f"dml_iv_{ESTIMATOR_MODE}_with_first_stage.xlsx"
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        results_df.to_excel(writer, sheet_name="all_results", index=False)
        results_df[results_df["config"] == "baseline"].to_excel(writer, sheet_name="baseline_results", index=False)
        sensitivity_df.to_excel(writer, sheet_name="sensitivity_summary", index=False)

        if not first_stage_df.empty:
            first_stage_df.to_excel(writer, sheet_name="first_stage_diag", index=False)

        if not first_stage_summary_df.empty:
            first_stage_summary_df.to_excel(writer, sheet_name="first_stage_summary", index=False)

        settings = pd.DataFrame({
            "key": [
                "data_path", "out_dir", "estimator_mode", "n_splits", "n_reps", "random_seed",
                "y1", "y2", "x", "id", "year", "type1"
            ],
            "value": [
                str(DATA_PATH), str(OUT_DIR), ESTIMATOR_MODE, N_SPLITS, N_REPS, RANDOM_SEED,
                Y1, Y2, X, ID, YEAR, TYPE1
            ]
        })
        settings.to_excel(writer, sheet_name="settings", index=False)

        rf_json = pd.DataFrame({
            "config": list(RF_CONFIGS.keys()),
            "params_json": [json.dumps(v, ensure_ascii=False) for v in RF_CONFIGS.values()]
        })
        rf_json.to_excel(writer, sheet_name="rf_configs", index=False)

    print(f"\n结果已导出到: {out_path}")
    print("\n=== baseline 主结果 ===")
    print(results_df[results_df["config"] == "baseline"])

    if not first_stage_summary_df.empty:
        print("\n=== 第一阶段汇总 ===")
        print(first_stage_summary_df)


if __name__ == "__main__":
    main()
