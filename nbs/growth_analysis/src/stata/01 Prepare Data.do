/* This file loads the raw data from the noted sources, cleans the relevant variables, 
and saves this combined dataset for analysis in the subsequent scripts. */

*****************
*** PREP DATA ***
*****************
	
	*** Load Maddison data which can be downloaded from: https://www.rug.nl/ggdc/historicaldevelopment/maddison/
		tempfile maddison
		use "$input/mpd2018.dta", clear
		drop i_cig i_bm rgdpnapc
		rename (countrycode country cgdppc pop) (ccode country mad mad_pop)
		drop if year <1950
		*** Drop former countries
			drop if ccode == "PRI" // Puerto Rico
			drop if ccode == "SUN" // Former USSR
			drop if ccode == "CSK" // Czechoslovakia
			drop if ccode == "YUG" // Former Yugoslavia
		replace mad_pop = mad_pop/1000
		save `maddison'
		
	*** Load WDI data which can be downloaded from: http://databank.worldbank.org/data/source/world-development-indicators
		tempfile wdi
		import delimited "$input/wdi_data.csv", clear
		forval i = 5/62 {
			local year = `i' + 1955
			rename v`i' value`year'
		}	
		drop if _n == 1
		drop if missing(v2)
		destring value*, force replace
		replace v3 = "pop" if v3 == "Population, total"
		replace v3 = "gdpppp" if regexm(v3,"PPP")==1
		replace v3 = "gdpconst" if regexm(v3,"2010")==1
		replace v3 = "gdpconstlcu" if regexm(v3, "LCU")==1
		rename (v1 v2) (country ccode)
		drop v4
		reshape long value, i(country ccode v3) j(year)
		reshape wide value, i(country ccode year) j(v3) string
		rename value* *
		drop if missing(gdpppp) & missing(gdpconst) 
		sort ccode year
		// For years prior to when PPP data is available, apply growth rates from constant national dollars retroactively 
		by ccode: gen gdpconstgrowth = gdpconst/gdpconst[_n-1]
		gsort ccode - year
		replace gdpppp = gdpppp[_n - 1]/gdpconstgrowth[_n - 1] if missing(gdpppp) & !missing(gdpppp[_n - 1]) & !missing(gdpconst) & !missing(gdpconst[_n - 1])
		rename (gdpconst gdpppp pop) (wdi_const wdi wdi_pop)
		replace wdi_pop = wdi_pop/1000000
		drop gdpconstgrowth wdi_const
		save `wdi'
		
	*** Load PWT data which can be downloaded from: https://www.rug.nl/ggdc/productivity/pwt/	
		use "$input/pwt90.dta", clear
		rename countrycode ccode
		keep country ccode year pop rgdpe 
		rename (pop rgdpe) (pwt_pop pwt)
		foreach var in pwt {
			replace `var' = `var'/pwt_pop
		}
		drop if missing(pwt_pop)
		
	*** Add in Maddison and WDI
		mmerge ccode year using `maddison'
		mmerge ccode year using `wdi'
		drop _merge

	*** Oil-producers from IMF (http://datahelp.imf.org/knowledgebase/articles/516096-which-countries-comprise-export-earnings-fuel-a)
		gen oil = ccode == "DZA" | ///
			ccode == "AGO" | ///
			ccode == "AZE" | ///
			ccode == "BHR" | ///
			ccode == "BRN" | ///
			ccode == "TCD" | ///
			ccode == "COG" | ///
			ccode == "ECU" | ///
			ccode == "GNQ" | ///
			ccode == "GAB" | ///
			ccode == "IRN" | ///
			ccode == "IRQ" | ///
			ccode == "KAZ" | ///
			ccode == "KWT" | ///
			ccode == "NGA" | ///
			ccode == "OMN" | ///
			ccode == "QAT" | ///
			ccode == "RUS" | ///
			ccode == "SAU" | ///
			ccode == "TTO" | ///
			ccode == "TKM" | ///
			ccode == "ARE" | ///
			ccode == "VEN" | ///
			ccode == "YEM" | ///
			ccode == "LBY" | ///
			ccode == "TLS" | ///
			ccode == "SDN"
		gen nooil = 1-oil
		
	*** Small countries
		foreach data in mad pwt wdi {
			gen big_`data' = `data'_pop>=1 if !missing(`data'_pop)
		}
			
	*** Restrict sample
		foreach var in mad pwt wdi {
			replace `var' = . if big_`var'==0
		}
		drop if oil==1
		keep ccode country year pwt wdi mad *pop* 
		
	*** World Bank classifications downloaded from: https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank-country-and-lending-groups
		preserve
			import excel "$input/OGHIST.xls", sheet("Country Analytical History") cellrange(A5:AF229) clear
			rename A ccode
			rename B country
			rename D group1990
			drop if _n<8
			keep ccode country group1990
			tempfile groups
			save `groups', replace
		restore
		mmerge ccode using `groups', unmatched(master)
		drop _merge
save "$output/combined_data.dta", replace	
	
exit
