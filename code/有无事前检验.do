use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta", clear

drop if year <= 2012

*==============================================
*                 变量配置
*==============================================
local Y1       "TFP_LP"
local Y2       "TFP_OP"
local X        "GGF"
local ID       "股票代码"
local YEAR     "year"
local TYPE1    "level"     // 0=低投，1=高投
local A        "a"         // 0=未投，1=低投，2=高投

local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"
local OUT "/Users/lmm/Documents/Replication_Package_副本/out"

*==============================================
*               基础检查
*==============================================
capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace

capture which ftools
if _rc ssc install ftools, replace

capture which psmatch2
if _rc ssc install psmatch2, replace

xtset `ID' `YEAR'

fvset base 0 `X'
fvset base 0 `TYPE1'

* 确认a的真实编码
tab `A', nolabel

* 清理旧变量
capture drop _pscore _weight _support _treated _id _nk _nn
capture drop psm_ln psm_hn psm_hl

* 清理旧结果
capture estimates drop ln_lp ln_lp_c hn_lp hn_lp_c hl_lp hl_lp_c
capture estimates drop ln_op ln_op_c hn_op hn_op_c hl_op hl_op_c

*========================================================
* 一、低投 vs 未投
* 样本：a=0,1
* 这时GGF就代表"低投vs未投"
*========================================================
preserve
    keep if inlist(`A', 0, 1)

    capture drop _pscore _weight _support _treated _id _nk _nn
    capture drop psm_ln

    tab `A'
    tab `X'

    * PSM：在该子样本中，用GGF匹配
    psmatch2 `X' `CTRLS_firm', neighbor(4) logit common ties

    gen psm_ln = 0
    replace psm_ln = 1 if _support == 1 & !missing(_weight)

    * TFP_LP
    reghdfe `Y1' `X' if psm_ln == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store ln_lp

    reghdfe `Y1' `X' `CTRLS_firm' if psm_ln == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store ln_lp_c

    * TFP_OP
    reghdfe `Y2' `X' if psm_ln == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store ln_op

    reghdfe `Y2' `X' `CTRLS_firm' if psm_ln == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store ln_op_c
restore

*========================================================
* 二、高投 vs 未投
* 样本：a=0,2
* 这时GGF就代表"高投vs未投"
*========================================================
preserve
    keep if inlist(`A', 0, 2)

    capture drop _pscore _weight _support _treated _id _nk _nn
    capture drop psm_hn

    tab `A'
    tab `X'

    * PSM：在该子样本中，用GGF匹配
    psmatch2 `X' `CTRLS_firm', neighbor(4) logit common ties

    gen psm_hn = 0
    replace psm_hn = 1 if _support == 1 & !missing(_weight)

    * TFP_LP
    reghdfe `Y1' `X' if psm_hn == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hn_lp

    reghdfe `Y1' `X' `CTRLS_firm' if psm_hn == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hn_lp_c

    * TFP_OP
    reghdfe `Y2' `X' if psm_hn == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hn_op

    reghdfe `Y2' `X' `CTRLS_firm' if psm_hn == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hn_op_c
restore

*========================================================
* 三、高投 vs 低投
* 样本：a=1,2
* 这时不能只回归GGF，必须保留交互项
*========================================================
preserve
    keep if inlist(`A', 1, 2)

    capture drop _pscore _weight _support _treated _id _nk _nn
    capture drop psm_hl

    tab `A'
    tab `X'
    tab `TYPE1'

    * PSM：在"仅有低投和高投"的样本里，用GGF匹配
    psmatch2 `X' `CTRLS_firm', neighbor(4) logit common ties

    gen psm_hl = 0
    replace psm_hl = 1 if _support == 1 & !missing(_weight)

    * TFP_LP
    reghdfe `Y1' i.`X'##i.`TYPE1' if psm_hl == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hl_lp

    reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm' if psm_hl == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hl_lp_c

    * TFP_OP
    reghdfe `Y2' i.`X'##i.`TYPE1' if psm_hl == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hl_op

    reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm' if psm_hl == 1, ///
        absorb(`ID' `YEAR') vce(cluster `ID')
    estimates store hl_op_c
restore

*========================================================
* 四、输出：LP
*========================================================
esttab ln_lp ln_lp_c hn_lp hn_lp_c hl_lp hl_lp_c using "`OUT'/回归结果_PSM_分组三比较_LP.rtf", ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("观测值" "调整R²")) ///
    title("PSM匹配后分组三比较回归结果（TFP_LP）") ///
    mtitle("低投vs未投-无控制" "低投vs未投-有控制" "高投vs未投-无控制" "高投vs未投-有控制" "高投vs低投-无控制" "高投vs低投-有控制") ///
    label varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    replace


*========================================================
* 六、第三组（高投vs低投）的解释性检验
*========================================================

* LP 有控制
est restore hl_lp_c
display "------ TFP_LP 有控制模型：低投组中GGF效应 ------"
lincom 1.`X'

display "------ TFP_LP 有控制模型：高投相对低投的增量效应 ------"
lincom 1.`X'#1.`TYPE1'

display "------ TFP_LP 有控制模型：高投组中GGF总效应 ------"
lincom 1.`X' + 1.`X'#1.`TYPE1'
