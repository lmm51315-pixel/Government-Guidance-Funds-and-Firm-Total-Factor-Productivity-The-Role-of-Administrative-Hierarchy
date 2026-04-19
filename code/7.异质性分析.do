use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta", clear

*==============================================
*                 变量配置
*==============================================
local Y        "TFP_LP"          // 被解释变量
local X        "GGF"
local ID       "股票代码"
local YEAR     "year"
local TYPE1    "level"           // 高层级基金样本标记
local CTRLS    "lev roa cash growth Big4 两职合一 独立董事占比 股权集中度 soe"

local OUT      "/Users/lmm/Documents/Replication_Package_副本/out"

*==============================================
*               基础检查
*==============================================
capture which reghdfe
if _rc ssc install reghdfe, replace

capture which esttab
if _rc ssc install estout, replace

capture which ftools
if _rc ssc install ftools, replace

capture which eststo
if _rc ssc install estout, replace

xtset `ID' `YEAR'

*==============================================
* Step 1: 先在全样本构造"政策前"分组变量
* 注意：必须先构造，再删估计期样本
*==============================================

*----------- SF 分组 -----------
bysort `ID': egen SF_pre = median(cond(`YEAR' <= 2012, SF, .))
egen SF_pre_med = median(SF_pre)

gen SF_pre_grp = .
replace SF_pre_grp = 1 if SF_pre >= SF_pre_med & !missing(SF_pre)
replace SF_pre_grp = 0 if SF_pre <  SF_pre_med & !missing(SF_pre)

label define SF_pre_grp_lbl 1 "较高" 0 "较低", replace
label values SF_pre_grp SF_pre_grp_lbl
label var SF_pre_grp "政策前SF分组"

*----------- KV 分组 -----------
bysort `ID': egen KV_pre = median(cond(`YEAR' <= 2012, KV稳健性, .))
egen KV_pre_med = median(KV_pre)

gen KV_pre_grp = .
replace KV_pre_grp = 1 if KV_pre >= KV_pre_med & !missing(KV_pre)
replace KV_pre_grp = 0 if KV_pre <  KV_pre_med & !missing(KV_pre)

label define KV_pre_grp_lbl 1 "较高" 0 "较低", replace
label values KV_pre_grp KV_pre_grp_lbl
label var KV_pre_grp "政策前KV分组"

*----------- labprod1 分组 -----------
bysort `ID': egen labprod1_pre = median(cond(`YEAR' <= 2012, labprod1, .))
egen labprod1_pre_med = median(labprod1_pre)

gen labprod1_pre_grp = .
replace labprod1_pre_grp = 1 if labprod1_pre >= labprod1_pre_med & !missing(labprod1_pre)
replace labprod1_pre_grp = 0 if labprod1_pre <  labprod1_pre_med & !missing(labprod1_pre)

label define labprod1_pre_grp_lbl 1 "较高" 0 "较低", replace
label values labprod1_pre_grp labprod1_pre_grp_lbl
label var labprod1_pre_grp "政策前labprod1分组"

*==============================================
* Step 2: 保留估计样本
*==============================================
keep if `YEAR' > 2012

*==============================================
* Step 3: 分组回归（高层级基金样本内）
*==============================================
eststo clear

*----------------------------
* (1) SF较高
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & SF_pre_grp==1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m1
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*----------------------------
* (2) SF较低
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & SF_pre_grp==0, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m2
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*----------------------------
* (3) KV较高
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & KV_pre_grp==1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m3
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*----------------------------
* (4) KV较低
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & KV_pre_grp==0, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m4
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*----------------------------
* (5) labprod1较高
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & labprod1_pre_grp==1, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m5
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*----------------------------
* (6) labprod1较低
*----------------------------
qui reghdfe `Y' `X' `CTRLS' if `TYPE1'==1 & labprod1_pre_grp==0, ///
    absorb(`ID' `YEAR') vce(cluster `ID')
eststo m6
estadd local Controls "YES"
estadd local FirmFE  "YES"
estadd local YearFE  "YES"

*==============================================
* Step 4: 输出表格
*==============================================
esttab m1 m2 m3 m4 m5 m6 using "`OUT'/表5_异质性分析结果.rtf", ///
    replace ///
    b(3) t(2) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    keep(`X' _cons) ///
    order(`X' _cons) ///
    coeflabels(`X' "GGF" _cons "Constant") ///
    cells(b(star fmt(3)) t(par fmt(2))) ///
    stats(Controls FirmFE YearFE N r2, ///
          fmt(0 0 0 0 3) ///
          labels("Controls" "Firm FE" "Year FE" "N" "R²")) ///
    mgroups("融资约束（SF）" "融资约束（KV）" "劳动生产率（labprod1）", ///
            pattern(1 0 1 0 1 0) ///
            span) ///
    mtitle("较高" "较低" "较高" "较低" "较高" "较低") ///
    title("表5异质性分析结果") ///
    nonotes ///
    compress
