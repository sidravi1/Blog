/* This do-file takes the data from "01 Prepare Data", calculates beta convergence
coefficients, and produces the associated graph. */

*************************
*** BETA COEFFICIENTS ***
*************************

	*** Load data
		use "$output/combined_data.dta", clear
		drop *_pop
		reshape wide $datasets, i(ccode country) j(year)
		*drop if pwt1990==.|wdi1990==.|mad1990==.
		
	*** Cycle through regressions
		local j = 1	
		foreach data in $datasets {			
			// Customize window by dataset
			if "`data'" != "wdi" {
				local firstyear = 1950 
			}
				else {
					local firstyear = 1960
					local lastyear = 2017
				}
			if "`data'" == "pwt" {
				local lastyear = 2014
			}
			if "`data'" == "mad" {
				local lastyear = 2016
			}	
			local endyear = `lastyear' - 1 		
				forval startyear = `firstyear'(1)`endyear' {
					gen outcome = ((log(`data'`lastyear'/`data'`startyear')/(`lastyear' - `startyear')) - 1)*100
					gen initial = log(`data'`startyear')
					qui reg outcome initial, robust  
					preserve
						clear
						set obs 1
						tempfile file`j'
						gen measure = "`data'"
						gen beta = _b[initial]
						gen se = _se[initial]
						gen lower = _b[initial] - invttail(`e(df_r)',0.025)*_se[initial]
						gen upper = _b[initial] + invttail(`e(df_r)',0.025)*_se[initial]
						gen tstat = _b[initial]/_se[initial]
						gen pval =2*ttail(`e(df_r)',abs(tstat))
						gen n = `e(N)'
						gen startyear = `startyear'
						save `file`j''
					restore
					drop outcome initial
					local ++ j
				}
		}
	
	*** Combine results
		clear
		local jminus1 = `j' - 1
		forval i = 1/`jminus1' {
			append using `file`i''
		}
		
	*** Stagger years for graph
		gen startyear2 = startyear + .2
		gen startyear3 = startyear + .4
	
		#delimit ;
		tw  (rcap lower upper startyear if measure == "mad" & startyear >=1960 & startyear <= 2000, lcolor(gs10)) 	
			(sc beta startyear if measure == "mad" & startyear >=1960 & startyear <= 2000, mcolor(plg1))	
			(rcap lower upper startyear2 if measure == "pwt" & startyear >=1960 & startyear <= 2000, lcolor(gs10)) 	
			(sc beta startyear2 if measure == "pwt" & startyear >=1960 & startyear <= 2000, mcolor(black) msymbol(D))
			(rcap lower upper startyear3 if measure == "wdi" & startyear >=1960 & startyear <= 2000, lcolor(gs10)) 	
			(sc beta startyear3 if measure == "wdi" & startyear >=1960 & startyear <= 2000, mcolor(plb1) msymbol(S)), 	
			plotregion(style(none) lcolor(none)) yline(0,lcolor(black) lwidth(medium)) xlabel(1960(5)2000, angle(45)) 
				graphregion(fcol(white) lcol(white)) 
				title("{&beta}-coefficient of unconditional convergence", size(medlarge))
				subtitle("Regressing real per capita GDP growth to present day""on the log of initial per capita GDP", size(small))
				ytitle("{&beta}", orientation(horizontal) size(large)) 
				xtitle("Initial Year") xsize(4) ysize(6)
				note("Each point represents the coefficient from a separate, bivariate""regression. The dependent variable is the annual real per capita""growth rate from the year listed until the most recent data round.""The independent variable is the log of real per capital GDP in the""base year.""NB: Sample excludes oil-rich countries (i.e. 'Export Earnings: Fuel'""in IMF DOTS), and countries with populations under 1 million.")
				legend(order(	2 "Maddison" 
								4 "PWT"
								6 "WDI") pos(2) ring(0) col(1)
								region(lcolor(none) fcolor(none)));
		#delimit cr
		gr_edit .style.editstyle declared_ysize(6) editcopy
		gr_edit .style.editstyle declared_xsize(4) editcopy
		graph export "$figures/beta_by_series.pdf", replace
		graph export "$figures/beta_by_series.png", replace
		
exit
	
