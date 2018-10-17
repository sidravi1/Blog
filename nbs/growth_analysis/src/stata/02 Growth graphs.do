/* This do-file takes the data from "01 Prepare Data", 
calculates simple growth rates, and produces graphs
of local polynomial regressions of growth on initial
GDP levels for 1960-present and 2000-present. */

use "$output/combined_data.dta", clear

*** Growth rates
	encode ccode, g(cccode)
	sort cccode year
	tsset cccode year
	foreach var in pwt wdi mad{
		gen g`var' = 100*((`var'/l.`var')-1)
	}
	
*** Create lags and growth rates from various start dates
	foreach y in 1960 /*1980 1985 1990 1995*/ 2000{
		local pwt = 2014-`y'
		local wdi = 2017-`y'
		local mad = 2016-`y'
		foreach var in pwt wdi mad{
			gen `var'`y' = l``var''.`var' if year==`y'+``var''
			gen l`var'`y' = ln(`var'`y')
			gen g`var'`y' = 100*((`var'/`var'`y')^(1/``var'')-1)
		}
	}
	
*** Regress growth on levels, non-parametric
	tokenize `""PWT 9.0, Chained PPP""WDI, 2011 PPP""Maddison, 2011 USD""'
	local i = 1
	#delimit ;
	foreach var in pwt wdi mad{;
		foreach y in 1960 /*1980 1985 1990 1995*/ 2000{;
			preserve;
				drop if l`var'`y'<ln(400);
				twoway	(lpolyci g`var'`y' l`var'`y')
						(scatter g`var'`y' l`var'`y' [w=`var'_pop] if g`var'`y'<10 & g`var'`y'>-2, mcolor(navy%30))
						(scatter g`var'`y' l`var'`y' if ccode=="IND"|ccode=="CHN"|ccode=="PAK"|ccode=="BGD"|ccode=="BRA"|ccode=="RUS"|ccode=="NGA"|ccode=="USA"|ccode=="IDN"|ccode=="JPN", msymbol(none) mlabpos(0) mlabel(ccode) mlabcolor(black)),
						title("`y'-present")
						ytitle("Growth rate (%)")
						xtitle("Per capita GDP in `y', log scale")
						xlabel(6.9 "$1,000" 8.5 "$5,000" 10.1 "$25,000")
						legend(off)
						saving("$figures/lpoly_growth_`var'`y'", replace);
			restore;
		};
		graph combine	"$figures/lpoly_growth_`var'1960"
						"$figures/lpoly_growth_`var'2000",
						col(2) ycommon
						title("``i''")
						saving("$figures/lpoly_`var'", replace);
		local ++i;
	};
	#delimit cr
	

*** Combine graphs
	#delimit ;
	graph combine	"$figures/lpoly_pwt"
					"$figures/lpoly_wdi"
					"$figures/lpoly_mad",
					title("Growth and Initial GDP")
					col(1);
	#delimit cr
	gr_edit .style.editstyle declared_ysize(6) editcopy
	gr_edit .style.editstyle declared_xsize(4) editcopy
	graph export "$figures/lpoly_growth_2x3.pdf", replace
	graph export "$figures/lpoly_growth_2x3.png", replace

exit
