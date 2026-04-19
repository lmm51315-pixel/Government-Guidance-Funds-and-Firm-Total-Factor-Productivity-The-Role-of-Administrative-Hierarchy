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
local CITY     "所属城市代码"
local PROV     "所属省份代码"
local IND      "行业代码"

* 控制变量
local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

* 异质性变量
local TYPE1    "level"

*==============================================
*               基础检查
*==============================================
capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace

capture which ftools
if _rc ssc install ftools, replace

capture which estadd
if _rc ssc install estout, replace

* 面板设定
xtset `ID' `YEAR'

*==============================================
*         构造更严格固定效应
*==============================================
capture drop indyear
capture drop provyear

egen indyear  = group(`IND' `YEAR')
egen provyear = group(`PROV' `YEAR')

* 清除之前存储的估计结果
capture estimates drop rob1 rob2 rob3 rob4 rob5 rob6

*==============================================
* 稳健性检验1：剔除突发事件年份
* 保留2018年及以前 + 2023年
*==============================================

reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm' ///
    if (`YEAR' <= 2018 | `YEAR' == 2023), ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store rob1
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm' ///
    if (`YEAR' <= 2018 | `YEAR' == 2023), ///
    absorb(`ID' `YEAR') vce(cluster `ID')
estimates store rob2
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

*==============================================
* 稳健性检验2：行业×年份固定效应
*==============================================

reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm', ///
    absorb(`ID' indyear) vce(cluster `ID')
estimates store rob3
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm', ///
    absorb(`ID' indyear) vce(cluster `ID')
estimates store rob4
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

*==============================================
* 稳健性检验3：省份×年份固定效应
*==============================================

reghdfe `Y1' i.`X'##i.`TYPE1' `CTRLS_firm', ///
    absorb(`ID' provyear) vce(cluster `ID')
estimates store rob5
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm', ///
    absorb(`ID' provyear) vce(cluster `ID')
estimates store rob6
capture noisily testparm i.`X'#i.`TYPE1'
capture estadd scalar p_inter = r(p)

*==============================================
* 输出稳健性检验结果
*==============================================
esttab rob1 rob2 rob3 rob4 rob5 rob6 using "/Users/lmm/Documents/Replication_Package_副本/out/回归结果_稳健性_level.rtf", ///
    b(3) se(3) ///
    star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2_a p_inter, fmt(0 3 3) labels("观测值" "调整R²" "交互项联合检验p值")) ///
    title("GGF与行政层级特征异质性的稳健性检验") ///
    mtitle("LP-剔除冲击" "OP-剔除冲击" ///
           "LP-行业×年份FE" "OP-行业×年份FE" ///
           "LP-省份×年份FE" "OP-省份×年份FE") ///
    label ///
    varwidth(20) ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    collabels(none) ///
    replace

	
* TFP_OP，有控制变量
reghdfe `Y2' i.`X'##i.`TYPE1' `CTRLS_firm', ///	
    absorb(`ID' `YEAR') vce(cluster `ID')

* TFP_GMM，有控制变量
reghdfe TFP_GMM i.`X'##i.`TYPE1' `CTRLS_firm', ///	
    absorb(`ID' `YEAR') vce(cluster `ID')
