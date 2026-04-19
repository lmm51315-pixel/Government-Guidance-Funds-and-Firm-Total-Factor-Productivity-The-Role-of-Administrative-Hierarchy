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
local TYPE1    "level"

local CTRLS_firm "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

* 清除面板设定，避免bootstrap后出现 repeated time values within panel
capture xtset, clear

*==============================================
*               基础检查
*==============================================
capture which reghdfe
if _rc ssc install reghdfe, replace

capture which ftools
if _rc ssc install ftools, replace

capture which coefstability
if _rc ssc install coefstability, replace

*==============================================
*        手工生成交互项（适用于Oster检验）
*==============================================
capture drop GGF_level
gen GGF_level = `X' * `TYPE1'
label var GGF_level "GGF×level"


*==============================================
*         delta=1,rmax=1.3
*==============================================

    *--------------------------
    * TFP_LP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y1' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1) ///
        beta(0) ///
        rmax(1.3)
    *--------------------------
    * TFP_OP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y2' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1) ///
        beta(0) ///
        rmax(1.3)

*==============================================
*         delta=1.5,rmax=1，3
*==============================================

    *--------------------------
    * TFP_LP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y1' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1.5) ///
        beta(0) ///
        rmax(1.3)
    *--------------------------
    * TFP_OP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y2' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1.5) ///
        beta(0) ///
        rmax(1.3)
		
*==============================================
*         delta=1,rmax=2
*==============================================

    *--------------------------
    * TFP_LP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y1' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1) ///
        beta(0) ///
        rmax(2)
    *--------------------------
    * TFP_OP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y2' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1) ///
        beta(0) ///
        rmax(2)

*==============================================
*         delta=1.5,rmax=2
*==============================================

    *--------------------------
    * TFP_LP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y1' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1.5) ///
        beta(0) ///
        rmax(2)
    *--------------------------
    * TFP_OP
    *--------------------------
        coefstability GGF_level, ///
        model(`"reghdfe `Y2' GGF_level `CTRLS_firm', absorb(`ID' `YEAR') vce(cluster `ID')"') ///
        delta(1.5) ///
        beta(0) ///
        rmax(2)
