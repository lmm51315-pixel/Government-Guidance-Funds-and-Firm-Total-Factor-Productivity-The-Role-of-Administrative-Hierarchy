use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta", clear

drop if year <= 2012

*==============================================
*                 变量配置
*==============================================
local Y1       "TFP_LP"
local Y2       "TFP_OP"
local X        "GGF"              // 投资哑变量
local ID       "股票代码"          // 公司标识
local YEAR     "year"             // 时间标识
local CITY     "所属城市代码"      // 地理标识
local PROV     "所属省份代码"      // 省级标识
local IND      "行业代码"          // 行业标识
local TYPE1    "level"            // 行政层级：假定 1=高层级，0=低层级

* 控制变量：与基准回归保持一致
local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

* 输出路径
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

*==============================================
*               面板设定
*==============================================
xtset `ID' `YEAR'

* 设定基准组，便于解释交互项
fvset base 0 `X'
fvset base 0 `TYPE1'

* 清理旧变量
capture drop _pscore _weight _support _treated _id _nk _nn
capture drop pscore_raw cs_min cs_max psm_sample re_ps

* 清理旧估计结果
capture estimates drop psm_int1 psm_int2 psm_int3 psm_int4
capture estimates drop psm_g1 psm_g2 psm_g3 psm_g4

*==============================================
* Step 1: 先用 logit 估计倾向得分
*         用于共同支撑判断和匹配前核密度图
*==============================================
logit `X' `CTRLS_firm'
predict pscore_raw if e(sample), pr

*==============================================
* Step 2: 确定共同支撑区间
*==============================================
summarize pscore_raw if `X' == 1
local pscore_min_t = r(min)
local pscore_max_t = r(max)

summarize pscore_raw if `X' == 0
local pscore_min_c = r(min)
local pscore_max_c = r(max)

local common_support_min = max(`pscore_min_t', `pscore_min_c')
local common_support_max = min(`pscore_max_t', `pscore_max_c')

gen cs_min = `common_support_min'
gen cs_max = `common_support_max'

* 仅保留共同支撑区间内样本
keep if pscore_raw >= `common_support_min' & pscore_raw <= `common_support_max'

*==============================================
* Step 3: 倾向得分匹配
*         这里用 GGF 做处理变量，和主回归保持一致
*==============================================
psmatch2 `X' `CTRLS_firm', neighbor(4) logit common ties

* 匹配样本标记
gen psm_sample = 0
replace psm_sample = 1 if _support == 1 & !missing(_weight)

*==============================================
* Step 4: 匹配效果检验
*==============================================
pstest `CTRLS_firm', both graph

graph export "`OUT'/pstest_balance_graph.png", replace

*==============================================
* Step 5: 匹配前后倾向得分核密度图
*==============================================

*----------- 匹配前 -----------
gen re_ps = pscore_raw

twoway ///
    (kdensity re_ps if `X' == 1, lpattern(solid) lcolor(black) lwidth(medium) ///
        scheme(s1mono) ///
        ytitle("{stSans:Kernel}{stSans:Density}", size(large) orientation(h)) ///
        xtitle("{stSans:Propensity Score}", size(large)) ///
        legend(label(1 "{stSans:Treated group}") size(medium) position(1) symxsize(10)) ///
        plotregion(margin(3 3 3 3))) ///
    (kdensity re_ps if `X' == 0, lpattern(dash) lcolor(black) lwidth(medium) ///
        legend(label(2 "{stSans:Control group}") size(medium) position(1) symxsize(10))), ///
    ylabel(, labsize(medium)) ///
    title("Kernel Density Estimation of Propensity Score (Before Matching)", ///
        size(large) color(black) align(center) margin(0 0 2 0)) ///
    graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
    plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
    xscale(lcolor(black)) yscale(lcolor(black))

graph export "`OUT'/kdensity_before_matching.png", replace

*----------- 匹配后 -----------
twoway ///
    (kdensity _pscore if `X' == 1 & psm_sample == 1, lpattern(solid) lcolor(black) lwidth(medium) ///
        scheme(s1mono) ///
        ytitle("{stSans:Kernel}{stSans:Density}", size(large) orientation(h)) ///
        xtitle("{stSans:Propensity Score}", size(large)) ///
        legend(label(1 "{stSans:Treated group}") size(medium) position(1) symxsize(10)) ///
        plotregion(margin(3 3 3 3))) ///
    (kdensity _pscore if `X' == 0 & psm_sample == 1, lpattern(dash) lcolor(black) lwidth(medium) ///
        legend(label(2 "{stSans:Control group}") size(medium) position(1) symxsize(10))), ///
    ylabel(, labsize(medium)) ///
    title("Kernel Density Estimation of Propensity Score (After Matching)", ///
        size(large) color(black) align(center) margin(0 0 2 0)) ///
    graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
    plotregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white)) ///
    xscale(lcolor(black)) yscale(lcolor(black))

graph export "`OUT'/kdensity_after_matching.png", replace

*==============================================
* Step 6A: 匹配后交互项回归
*          与主回归口径一致：GGF × level
*==============================================

* 模型1：TFP_LP，无控制变量
reghdfe `Y1' i.`X'##i.`TYPE1' if psm_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store psm_int1

* 模型2：TFP_LP，有控制变量
reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm' if psm_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store psm_int2

* 模型3：TFP_OP，无控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' if psm_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store psm_int3

* 模型4：TFP_OP，有控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm' if psm_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store psm_int4

* 输出：匹配后交互项结果
esttab psm_int1 psm_int2 psm_int3 psm_int4 using "`OUT'/回归结果_PSM_交互项_level.rtf", ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("观测值" "调整R²")) ///
    title("PSM匹配后GGF与行政层级特征的异质性回归结果") ///
    mtitle("LP-无控制" "LP-有控制" "OP-无控制" "OP-有控制") ///
    label ///
    varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    replace


*==============================================
* Step 7: 交互项回归中的组别总效应检验
*==============================================

* 在 LP 有控制模型中：
est restore psm_int2
display "------ TFP_LP 有控制模型：低层级组中 GGF 效应 ------"
lincom 1.`X'

display "------ TFP_LP 有控制模型：高层级组中 GGF 总效应 ------"
lincom 1.`X' + 1.`X'#1.`TYPE1'

* 在 OP 有控制模型中：
est restore psm_int4
display "------ TFP_OP 有控制模型：低层级组中 GGF 效应 ------"
lincom 1.`X'

display "------ TFP_OP 有控制模型：高层级组中 GGF 总效应 ------"
lincom 1.`X' + 1.`X'#1.`TYPE1'
