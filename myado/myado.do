* ===================================================
* 外部命令安装脚本
* 功能：安装运行本程序所需的外部Stata命令
* 作者：马俊豪
* ===================================================

* -------------------------------------------
* 主要命令安装
* -------------------------------------------

* 安装高维固定效应回归命令
ssc install reghdfe, replace  

* 安装回归结果输出工具
ssc install estout, replace 

* 安装科学图表模板
ssc install scheme_scientific, replace   

* 安装汇总统计工具
ssc install fsum, replace        

* 安装 shellout 工具包
ssc install texdoc, replace


  
