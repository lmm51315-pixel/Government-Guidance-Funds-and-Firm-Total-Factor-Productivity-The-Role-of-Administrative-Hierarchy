* 导入数据
*import excel "/Users/lmm/Documents/Replication_Package_副本/data/rawdata.xlsx", sheet("Sheet1") firstrow clear
*save "/Users/lmm/Documents/Replication_Package_副本/data/rawdata.dta",replace
use "/Users/lmm/Documents/Replication_Package_副本/data/rawdata.dta",replace


rename 会计年度 year

*==============================================
*                 变量配置
*==============================================
* 定义主要变量名称 - 便于后续修改和维护
local Y        "TFP_LP"              // 
local X        "GGF"         // 
local ID       "股票代码"            // 公司标识
local YEAR     "year"            // 时间标识
local CITY     "所属城市代码"        // 地理标识
local PROV     "所属省份代码"        // 省级标识  
local IND      "行业代码"           // 行业标识

* 定义控制变量组
local CTRLS_firm   "资产负债率 总资产净利润率ROAB 每股企业自由现金流量 增长率 age Big4 两职合一 独立董事占比 股权集中度 "  
local CTRLS_region "金融业占比 第三产业占比"      // 区域经济结构 第三产业占比
local CTRLS_ind    "HHIC"                         // 行业集中度

*==============================================
*               创建标准化ID变量
*==============================================

* 公司ID - 确保为数值型分组变量
capture egen id = group(`ID'), label
if _rc != 0 {
    gen id = `ID'  // 如果分组失败，直接使用原变量
}

* 年份变量 - 确保为数值型
capture confirm numeric variable `YEAR'
if _rc != 0 {
    destring `YEAR', replace force  // 强制转换为数值
}
format `YEAR' %ty  // 设置为年份格式

* 城市ID - 处理字符型和数值型变量
capture confirm string variable `CITY'
if _rc == 0 {
    egen city_id = group(`CITY'), label  // 字符型转为分组数值
}
else {
    gen city_id = `CITY'  // 数值型直接使用
}

* 省份ID - 同上处理
capture confirm string variable `PROV'
if _rc == 0 {
    egen prov_id = group(`PROV'), label
}
else {
    gen prov_id = `PROV'
}

* 行业ID - 同上处理  
capture confirm string variable `IND'
if _rc == 0 {
    egen ind_id = group(`IND'), label
}
else {
    gen ind_id = `IND'
}

*==============================================
*               数据质量检查
*==============================================

* 检查并处理重复的公司-年份观测
duplicates report id `YEAR'          // 报告重复情况
duplicates tag id `YEAR', gen(dup)   // 标记重复观测
tab dup                                   // 查看重复分布
duplicates drop id `YEAR', force     // 删除重复，保留第一个
drop dup                                 // 清理临时变量

tsset id year

gen L1_fund_density1 = L.投资密度1
gen L2_fund_density1 = L2.投资密度1
gen L3_fund_density1 = L3.投资密度1
gen L4_fund_density1 = L4.投资密度1

gen L1_fund_density2 = L.投资密度2
gen L2_fund_density2 = L2.投资密度2
gen L3_fund_density2 = L3.投资密度2

*==============================================
*               面板数据设定
*==============================================

gen age2 = age*age
destring 增长率, replace force
* 剔除行业代码为 J 开头的数据
drop if substr(行业代码, 1, 1) == "J"
drop if substr(行业代码, 1, 1) == "K"
* 剔除上市状态为 ST 或 ST* 的数据
drop if inlist(上市状态, "ST", "ST*","*ST")
gen SF = abs(SA指数)
* 删除指定变量的缺失值
drop if missing(资产负债率, 总资产净利润率ROAB, 规模, 每股企业自由现金流量, 股权集中度,增长率, Big4, 两职合一, 独立董事占比, investdid,TFP_LP,产权性质)
drop if 营业收入 == 0
replace Loan = 0 if missing(Loan)

* 设定为公司-年份面板数据
xtset id `YEAR'

*==============================================
*               1% 和 99% 缩尾处理（Winsorize）
*==============================================

* 对于主要变量（例如因变量和自变量），执行1%和99%的缩尾处理
local variables "`Y' "  // 这里确保 `Y` 和 `X` 为你的因变量和自变量

foreach var of local variables {
    * 使用winsor2对变量进行1%和99%的缩尾处理，直接替换原变量
    winsor2 `var', cuts(1 99) replace   // replace选项用于直接修改原变量
}

* 对于控制变量中的每个变量执行winsorize处理
local CTRLS_firm "资产负债率 总资产净利润率ROAB 股权集中度 每股企业自由现金流量 规模 增长率 独立董事占比 " 

foreach var of local CTRLS_firm {
    * 使用winsor2对控制变量进行1%和99%的缩尾处理，直接替换原变量
    winsor2 `var', cuts(1 99) replace   // replace选项用于直接修改原变量
}

winsor2 Cost3, cuts(1 99) replace 
winsor2 analyze, cuts(1 99) replace 
winsor2 内部控制指数评分, cuts(1 99) replace 
winsor2 labprod2, cuts(1 99) replace
winsor2 企业生产经营效率1, cuts(1 99) replace
* 如果你有其他需要进行缩尾处理的变量，可以继续用相同的方法处理

*==============================================
*               变异情况检查
*==============================================

* 检查自变量在城市-年份层面的变异（识别要求）
preserve
    bysort city_id `YEAR': egen city_year_count = count(`X')
    collapse (mean) `X' (first) city_year_count, by(city_id `YEAR')
    xtset city_id `YEAR'
    xtsum `X'  // 显示组间和组内变异
restore

* 检查公司层面的变异
xtsum `X'

* 创建回归样本标识 - 包含所有变量的完整样本
gen sample = 1

* 确保核心变量不缺失
foreach var in `Y' `X' id `YEAR' city_id {
    replace sample = 0 if missing(`var')
}

* 确保控制变量不缺失
foreach var in `CTRLS_firm'  {
    capture confirm variable `var'
    if _rc == 0 {
        replace sample = 0 if missing(`var')
    }
}

drop if sample == 0 

drop 金融错配程度 资本化研发投入支出占研发投入的比例 资本化研发投入支出占当期净利润的比重 注册具体地址 成立日期 经营效率1 经营效率2 经营效率3 

* 生成每个个体首次接受处理的年份
bysort id (`YEAR'): egen  treatment_year = min(cond( `X'==1, `YEAR', .))

drop if year <= 2011
rename 资产负债率 lev
rename 总资产净利润率ROAB roa
rename 每股企业自由现金流量 cash

rename 规模 size
rename 托宾Q值A Q
rename 产权性质 soe
xtset id year

drop if missing(TFP_LP,TFP_OP,TFP_GMM,investdid,lev,roa,cash,增长率,Big4,两职合一,独立董事占比,股权集中度,soe,id,year,GGF)
* 检查每个id的观测值数量
replace early = 0 if missing(early)
replace level = 0 if missing(level)


bysort id: gen id_count = _N
tab id_count

* 查看被排除的观测中，有多少是单一观测值的个体
reghdfe TFP_LP investdid lev roa cash 增长率 size Big4 两职合一 独立董事占比 股权集中度 soe, ///
    absorb(id year) vce(cluster id)
gen used_sample = e(sample)

tab id_count if used_sample == 0
drop if used_sample == 0

gen HHI = 股权集中度/100
gen Independent = 独立董事占比/100
gen  growth = 增长率/100


gen GGF_high = (GGF==1 & level==1)
gen GGF_low  = (GGF==1 & level==0)

* 先按股票代码判断：是否在所有year上GGF都等于0
bysort 股票代码: egen any_GGF_nonzero = max(GGF != 0) if !missing(GGF)
* 生成三元变量 a
gen a = .
replace a = 0 if any_GGF_nonzero == 0
replace a = 1 if any_GGF_nonzero == 1 & level == 0
replace a = 2 if any_GGF_nonzero == 1 & level == 1

label define a_lbl 0 "GGF始终为0" 1 "GGF不恒为0且level=0" 2 "GGF不恒为0且level=1"
label values a a_lbl
label var a "按GGF和level构造的三元变量"


save "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta",replace


export excel ///
  TFP_LP TFP_OP TFP_GMM investdid lev roa cash growth size Big4 两职合一 Independent HHI soe id year L1_fund_density2 L2_fund_density2 ind_id ///
  L1_fund_density1 L2_fund_density1 early level GGF GGF_high GGF_low a ///
  using "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.xlsx", ///
  firstrow(variables) replace

drop if year <= 2012
sum TFP_LP TFP_OP TFP_GMM GGF level lev roa cash growth Big4 age 两职合一 Independent HHI soe 
