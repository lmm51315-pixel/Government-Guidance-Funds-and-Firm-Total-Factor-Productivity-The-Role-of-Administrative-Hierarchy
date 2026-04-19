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

* 控制变量
local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

* 异质性变量
local TYPE1    "level"            // 行政层级

*==============================================
*               基础检查
*==============================================
capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace

* 如果没装 ftools，也补装
capture which ftools
if _rc ssc install ftools, replace

* 面板设定
xtset `ID' `YEAR'

* 清除之前存储的估计结果
capture estimates drop early1 early2 early3 early4 level1 level2 level3 level4

*==============================================
*         level 异质性：GGF × level
*==============================================
* 如果 level 是二元变量（如 0/1），下面可直接运行
* 如果 level 是多分类变量（如 1=市级,2=省级,3=国家级），下面也能运行，
* 但交互项系数解释为"相对基准组的增量效应"

* 模型1：TFP_LP，无控制变量
reghdfe `Y1' i.`X'##i.`TYPE1', ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store level1

* 模型2：TFP_LP，有控制变量
reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm', ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store level2

* 如果 level 是二元变量（0/1），可直接检验 level=1 组总效应
capture noisily lincom 1.`X' + 1.`X'#1.`TYPE1', level(95)

* 模型3：TFP_OP，无控制变量
reghdfe `Y2' i.`X'##i.`TYPE1', ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store level3

* 模型4：TFP_OP，有控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm', ///	
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store level4

* 输出 level 结果
esttab level1 level2 level3 level4 using "/Users/lmm/Documents/Replication_Package_副本/out/回归结果_level.rtf", ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a, fmt(0 3) labels("观测值" "调整R²")) ///
    title("GGF与行政层级特征的异质性回归结果") ///
    mtitle("LP-无控制" "LP-有控制" "OP-无控制" "OP-有控制") ///
    label ///
    varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    replace





* 分组观察
reghdfe `Y1' `X' `CTRLS_firm' if a != 2, ///
    absorb(`ID' `YEAR') vce(cluster `ID')


reghdfe `Y1' `X' `CTRLS_firm' if a != 1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')


