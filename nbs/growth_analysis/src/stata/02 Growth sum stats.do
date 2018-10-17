use "$output/combined_data.dta", clear

	local y = 1990
	drop if year<`y'
	
*** Growth rates
	encode ccode, g(cccode)
	sort cccode year
	tsset cccode year
	foreach var in pwt wdi mad{
		gen g`var' = 100*((`var'/l.`var')-1)
	}

*** Combine upper- and lower-middle income
	replace group1990 = "M" if group1990=="LM" | group1990=="UM"

*** Collapse to mean GDP by country, then group
	drop if group1990=="" | group1990==".."
	collapse (mean) gpwt gwdi gmad /*[aw=`var'_pop]*/, by(ccode group1990)
	preserve
		collapse (mean) gpwt gwdi gmad /*[aw=`var'_pop]*/, by(group1990)
		gen n = 1
		list
		rename (gpwt gwdi gmad)(avepwt avewdi avemad) 
		reshape wide ave*, i(n) j(group1990) string
		tempfile ave
		save `ave'
	restore
	gen n = 1
	mmerge n using `ave'
	drop _merge
	
*** Stats we cite
	foreach var in pwt wdi mad{
		di "`var'"
		gen faster`var' = g`var' > ave`var'H
		sum faster`var' if group=="M"
	}
	
exit
