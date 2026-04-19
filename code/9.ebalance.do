use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta", clear

drop if year <= 2012
* 如果你的主样本本来就有限制，再手动加回下面这一行
* keep if sample == 1

*==============================================
*                 变量配置
*==============================================
local Y1       "TFP_LP"
local Y2       "TFP_OP"
local X        "GGF"              // 投资哑变量
local ID       "股票代码"          // 公司标识
local YEAR     "year"             // 时间标识
local CITY     "所属城市代码"
local PROV     "所属省份代码"
local IND      "行业代码"
local TYPE1    "level"            // 0=低层级，1=高层级（先用tab确认）

* 与基准回归保持一致的控制变量
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

capture which ebalance
if _rc ssc install ebalance, replace

capture which pstest
if _rc ssc install psmatch2, replace

xtset `ID' `YEAR'

fvset base 0 `X'
fvset base 0 `TYPE1'

* 清除旧变量
capture drop _webal
capture drop eb_sample
capture drop re_ps
capture drop c2_*
capture drop c3_*
capture drop cint*
capture drop dcint*

* 清除旧估计结果
capture estimates drop eb_int1 eb_int2 eb_int3 eb_int4
capture estimates drop eb_g1 eb_g2 eb_g3 eb_g4

*==============================================
* Step 1: 构造 entropy balancing 的平衡变量
* 思路保留：虚拟变量 + 连续变量 + 二/三阶矩 + 交互项
*==============================================

* 虚拟变量：与主回归控制变量保持一致
local dummies "两职合一 Big4 soe"

* 连续变量：与主回归控制变量保持一致
local cont "lev roa cash growth 独立董事占比 股权集中度"

*---------- 二阶、三阶矩 ----------
local cont2 ""
local cont3 ""

foreach v of local cont {
    gen c2_`v' = `v'^2
    gen c3_`v' = `v'^3
    label var c2_`v' "`v'^2"
    label var c3_`v' "`v'^3"
    local cont2 `cont2' c2_`v'
    local cont3 `cont3' c3_`v'
}

*---------- 连续变量两两交互 ----------
local cont_inter ""
local n : word count `cont'
local k = 1

forvalues i = 1/`n' {
    local v1 : word `i' of `cont'
    forvalues j = `=`i'+1'/`n' {
        local v2 : word `j' of `cont'
        gen cint`k' = `v1' * `v2'
        label var cint`k' "`v1' × `v2'"
        local cont_inter `cont_inter' cint`k'
        local ++k
    }
}

*---------- 虚拟变量 × 连续变量 交互 ----------
local dum_cont_inter ""
local k = 1

foreach d of local dummies {
    foreach v of local cont {
        gen dcint`k' = `d' * `v'
        label var dcint`k' "`d' × `v'"
        local dum_cont_inter `dum_cont_inter' dcint`k'
        local ++k
    }
}

* entropy balancing 用到的全部平衡变量
local ebvars "`dummies' `cont' `cont2' `cont3' `cont_inter' `dum_cont_inter'"

*==============================================
* Step 2: entropy balancing
* 处理变量改为 GGF，与主回归保持一致
*==============================================
set seed 12
ebalance `X' `ebvars', maxiter(5000) tolerance(1e-6)

* 有效加权样本标记
gen eb_sample = !missing(_webal)

*==============================================
* Step 3: 平衡性检验
* 建议图里只放核心控制变量，可读性更强
* 如需完整检验，可把 `CTRLS_firm' 改成 `ebvars'
*==============================================
pstest `ebvars', treat(`X') mw(_webal) both graph
graph export "`OUT'/ebalance_pstest_core_graph.png", replace

* 如需完整高阶矩/交互项平衡检验，可额外运行：
* pstest `ebvars', treat(`X') mw(_webal) both

*==============================================
* Step 4A: 加权后的交互项回归
* 与主文异质性口径一致：GGF × level
*==============================================

* 模型1：TFP_LP，无控制变量
reghdfe `Y1' i.`X'##i.`TYPE1' [aweight=_webal] if eb_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store eb_int1

* 模型2：TFP_LP，有控制变量
reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm' [aweight=_webal] if eb_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store eb_int2

* 模型3：TFP_OP，无控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' [aweight=_webal] if eb_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store eb_int3

* 模型4：TFP_OP，有控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm' [aweight=_webal] if eb_sample == 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store eb_int4

* 输出：entropy balancing 后交互项结果
esttab eb_int1 eb_int2 eb_int3 eb_int4 using "`OUT'/回归结果_ebalance_交互项_level.rtf", ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("观测值" "调整R²")) ///
    title("Entropy balancing后GGF与行政层级特征的异质性回归结果") ///
    mtitle("LP-无控制" "LP-有控制" "OP-无控制" "OP-有控制") ///
    label ///
    varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    replace

*==============================================
* Step 5: 交互项模型中的组别总效应检验
*==============================================

* LP 有控制模型
est restore eb_int2
display "------ TFP_LP 有控制模型：低层级组中 GGF 效应 ------"
lincom 1.`X'

display "------ TFP_LP 有控制模型：高层级组中 GGF 总效应 ------"
lincom 1.`X' + 1.`X'#1.`TYPE1'

* OP 有控制模型
est restore eb_int4
display "------ TFP_OP 有控制模型：低层级组中 GGF 效应 ------"
lincom 1.`X'

display "------ TFP_OP 有控制模型：高层级组中 GGF 总效应 ------"
lincom 1.`X' + 1.`X'#1.`TYPE1'
