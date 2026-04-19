use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata.dta",replace
save "/Users/lmm/Documents/Replication_Package_副本/data/cleandata-1.dta", replace

drop if year <= 2012

mat b = J(1000,1,0)  // 系数矩阵
mat se = J(1000,1,0) // 标准误矩阵 
mat p = J(1000,1,0)  // P值矩阵

set seed 12345
* 只对控制组进行安慰剂处理
forvalues i=1/1000{
    use "/Users/lmm/Documents/Replication_Package_副本/data/cleandata-1.dta", clear
    
    * 只在真实控制组中随机分配安慰剂处理
    gen placebo_treatment_group = 0
    gen placebo_policy_year = .
    
    * 对控制组随机分配
    bysort id: replace placebo_treatment_group = (runiform() < 0.1) if treatment_year == . & _n == 1  // 10%的控制组成为安慰剂处理组
    bysort id: replace placebo_treatment_group = placebo_treatment_group[1] if placebo_treatment_group == .
    
    bysort id: replace placebo_policy_year = floor(2012 + runiform()*(2023-2012+1)) if placebo_treatment_group == 1 & _n == 1
    bysort id: replace placebo_policy_year = placebo_policy_year[1] if placebo_policy_year == .
    
    * 生成安慰剂DID变量
    gen placebo_period = (year >= placebo_policy_year)
    gen placebo_did = placebo_treatment_group * placebo_period
    
    * 回归（可以包含真实处理变量进行比较）
    qui xtreg TFP_LP placebo_did lev roa cash growth  Big4 两职合一 独立董事占比 股权集中度 soe i.year, fe cluster(id)
    
    * 存储结果
    mat b[`i',1] = _b[placebo_did]
    mat se[`i',1] = _se[placebo_did]
    mat p[`i',1] = 2*ttail(e(df_r), abs(_b[placebo_did]/_se[placebo_did]))
}
* 矩阵转化为向量
svmat b, names(coef)
svmat se, names(se)
svmat p, names(pvalue)
* 删除空值并添加标签
drop if pvalue1 == .
label var pvalue1 p值
label var coef1 估计系数
keep coef1 se1 pvalue1  
gen tvalue = coef1/se1     // 计算t值
save placebo.dta, replace   //关于p值，估计系数的文件，要用作画图
local true_coef 0.049 // 真实的基准回归系数
* 计算基准回归系数的经验p值
count if coef1 >= `true_coef'  // 计算有多少个安慰剂回归系数大于或等于基准回归的系数
local count_placebo = r(N)  // 保存符合条件的回归系数数量
* 经验p值 = 安慰剂回归系数 >= 真实系数的比例
local empirical_p = `count_placebo' / _N  // _N 是数据集中的总行数，即安慰剂回归的次数

display "Empirical p-value: " `empirical_p'
* 计算coef1的平均值
summarize coef1
local mean_coef = r(mean)  // 获取coef1的均值

* 绘制核密度图，并添加真实值和均值的线
* 计算coef1的平均值



  sum coef1, detail

  twoway(scatter pvalue coef1,                                                  ///
             msy(oh) mcolor(black)                                              ///
             xline(0, lpattern(dash)      lcolor(black))                ///
             xline(0.094  , lpattern(solid)     lcolor(black))                ///
             yline( 0.1     , lpattern(shortdash) lcolor(black))                ///
             scheme(qleanmono)                                                  ///
             xtitle("Estimator"           , size(medlarge))                 ///
             ytitle("P Value" , size(medlarge) orientation(h))  ///
             saving(placebo_test_Pvalue2, replace)),                            ///
         xlabel(-0.12(0.04)0.12       , labsize(medlarge) format(%03.2f))                     ///
         ylabel(0(0.25)1, labsize(medlarge) format(%03.2f))

  graph export "/Users/lmm/Documents/Replication_Package_副本/out/placebo_test_Pvalue2.png", replace

  
  sum coef1, detail

  twoway(kdensity coef1,                                                                     /// 
             xline(0.094  , lpattern(solid) lcolor(black))                                 ///
             scheme(qleanmono)                                                               ///
             xtitle("Estimator"                        , size(medlarge))                 ///
             ytitle("Kernel Density", size(medlarge) orientation(h))  ///
             saving(placebo_test_Coefficient2, replace)),                                    ///
         xlabel(-0.1(0.02)0.1, labsize(medlarge) format(%03.2f))                                          ///
         ylabel(, labsize(medlarge) format(%02.1f))  // 绘制1,000次回归did的系数的核密度图

  graph export "/Users/lmm/Documents/Replication_Package_副本/out/placebo_test_Coefficient2.png", replace 








