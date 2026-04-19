use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta", clear

drop if year <= 2012

*==============================================
*                 变量配置
*==============================================
local X        "GGF"
local ID       "股票代码"
local YEAR     "year"
local TYPE1    "level"     // 0=低层级, 1=高层级
local M1       "Loan"
local M2       "analyze_p_log1"
local M3       "企业生产经营效率1"

local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace

capture which ftools
if _rc ssc install ftools, replace

xtset `ID' `YEAR'

fvset base 0 `X'
fvset base 0 `TYPE1'

capture estimates drop mech_cost3 mech_loan

*==============================================
* 机制检验：Loan
*==============================================
reghdfe `M1' i.`X'##i.`TYPE1' `CTRLS_firm' if `M1' < ., ///
    absorb(`ID' `YEAR') vce(cluster `ID')

* 低层级效应
lincom 1.`X'
local b_low  = r(estimate)
local p_low  = r(p)
local star_low = cond(`p_low' < 0.01, "***", ///
                 cond(`p_low' < 0.05, "**", ///
                 cond(`p_low' < 0.10, "*", "")))
local low_eff_disp : display %9.3f `b_low'
local low_eff_disp = trim("`low_eff_disp'")
local low_eff_disp "`low_eff_disp'`star_low'"

estadd local  low_eff_disp "`low_eff_disp'"
estadd scalar low_p = `p_low'

* 高层级总效应
lincom 1.`X' + 1.`X'#1.`TYPE1'
local b_high = r(estimate)
local p_high = r(p)
local star_high = cond(`p_high' < 0.01, "***", ///
                  cond(`p_high' < 0.05, "**", ///
                  cond(`p_high' < 0.10, "*", "")))
local high_eff_disp : display %9.3f `b_high'
local high_eff_disp = trim("`high_eff_disp'")
local high_eff_disp "`high_eff_disp'`star_high'"

estadd local  high_eff_disp "`high_eff_disp'"
estadd scalar high_p = `p_high'

* 高低层级差异
test 1.`X'#1.`TYPE1' = 0
estadd scalar diff_p = r(p)

estimates store mech_loan


*==============================================
* 机制检验：analyze
*==============================================
reghdfe `M2' i.`X'##i.`TYPE1' `CTRLS_firm' if `M2' < ., ///
    absorb(`ID' `YEAR') vce(cluster `ID')

* 低层级效应
lincom 1.`X'
local b_low  = r(estimate)
local p_low  = r(p)
local star_low = cond(`p_low' < 0.01, "***", ///
                 cond(`p_low' < 0.05, "**", ///
                 cond(`p_low' < 0.10, "*", "")))
local low_eff_disp : display %9.3f `b_low'
local low_eff_disp = trim("`low_eff_disp'")
local low_eff_disp "`low_eff_disp'`star_low'"

estadd local  low_eff_disp "`low_eff_disp'"
estadd scalar low_p = `p_low'

* 高层级总效应
lincom 1.`X' + 1.`X'#1.`TYPE1'
local b_high = r(estimate)
local p_high = r(p)
local star_high = cond(`p_high' < 0.01, "***", ///
                  cond(`p_high' < 0.05, "**", ///
                  cond(`p_high' < 0.10, "*", "")))
local high_eff_disp : display %9.3f `b_high'
local high_eff_disp = trim("`high_eff_disp'")
local high_eff_disp "`high_eff_disp'`star_high'"

estadd local  high_eff_disp "`high_eff_disp'"
estadd scalar high_p = `p_high'

* 高低层级差异
test 1.`X'#1.`TYPE1' = 0
estadd scalar diff_p = r(p)

estimates store  mech_analyze

*==============================================
* 机制检验：企业生产经营效率1
*==============================================
reghdfe `M3' i.`X'##i.`TYPE1' `CTRLS_firm' if `M2' < ., ///
    absorb(`ID' `YEAR') vce(cluster `ID')

* 低层级效应
lincom 1.`X'
local b_low  = r(estimate)
local p_low  = r(p)
local star_low = cond(`p_low' < 0.01, "***", ///
                 cond(`p_low' < 0.05, "**", ///
                 cond(`p_low' < 0.10, "*", "")))
local low_eff_disp : display %9.3f `b_low'
local low_eff_disp = trim("`low_eff_disp'")
local low_eff_disp "`low_eff_disp'`star_low'"

estadd local  low_eff_disp "`low_eff_disp'"
estadd scalar low_p = `p_low'

* 高层级总效应
lincom 1.`X' + 1.`X'#1.`TYPE1'
local b_high = r(estimate)
local p_high = r(p)
local star_high = cond(`p_high' < 0.01, "***", ///
                  cond(`p_high' < 0.05, "**", ///
                  cond(`p_high' < 0.10, "*", "")))
local high_eff_disp : display %9.3f `b_high'
local high_eff_disp = trim("`high_eff_disp'")
local high_eff_disp "`high_eff_disp'`star_high'"

estadd local  high_eff_disp "`high_eff_disp'"
estadd scalar high_p = `p_high'

* 高低层级差异
test 1.`X'#1.`TYPE1' = 0
estadd scalar diff_p = r(p)

estimates store mech_efficient

*==============================================
* 输出表6：机制检验结果
*==============================================
esttab mech_loan mech_analyze mech_efficient using ///
"/Users/lmm/Documents/Replication_Package_副本/out/机制检验结果.rtf", ///
    b(3) se(3) ///
    keep(1.`X' 1.`X'#1.`TYPE1') ///
    order(1.`X' 1.`X'#1.`TYPE1') ///
    coeflabels(1.`X' "GGF" ///
               1.`X'#1.`TYPE1' "GGF×高层级") ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(low_eff_disp low_p high_eff_disp high_p diff_p N r2_a, ///
          fmt(0 3 0 3 3 0 3) ///
          labels("低层级效应" "低层级效应p值" ///
                 "高层级总效应" "高层级总效应p值" ///
                 "高低层级差异p值" "观测值" "调整R²")) ///
    title("表6 机制检验结果") ///
    mtitle("Loan" "Analyze" "Efficient" ) ///
    label ///
    varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    addnotes("GGF表示低层级政府引导基金效应；GGF×高层级表示高层级相对低层级的增量效应。", ///
             "高层级总效应通过 lincom(GGF + GGF×高层级) 计算。") ///
    replace
