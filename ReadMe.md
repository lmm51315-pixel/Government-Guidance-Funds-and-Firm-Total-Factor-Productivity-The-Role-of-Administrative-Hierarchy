# Government Guidance Funds and Firm Total Factor Productivity: The Role of Administrative Hierarchy – Replication Package

* Author: Ma Junhao
* Email: lmm51315@163.com

## Overview

This repository contains the complete replication materials for the paper *"Government Guidance Funds and Firm Total Factor Productivity: The Role of Administrative Hierarchy"*.

## Contents

- **data**: Contains the datasets used in the paper.

  - `rawdata.xlsx` was compiled by the author using Python.
  - Running the Stata script `1.数据处理.do` on this file generates `cleandata.xlsx` and `cleandata.dta`. Both files contain identical data and serve as the final dataset for the regression analyses.
- **code**: Includes all Stata and Python scripts used in the main text. The scripts should be executed in the order specified.

## Instructions for Replication

- To use the custom Stata command `coefstability` provided in this package, please copy the file `coefstability.ado` to one of the following directories:

  - Windows: `C:\stata\ado\personal\`
  - Mac/Linux: `~/Documents/Stata/ado/personal/`
- **myado**: Contains the external commands required to run the Stata do-files.
- Before executing the provided do-files, please update the global macro `PP` to reflect the path of the project folder on your machine. No other modifications to the code are necessary.

## Additional Notes

- Due to the large size of the original dataset, it cannot be uploaded directly to this repository. Researchers interested in accessing the raw data are encouraged to contact the author directly.
