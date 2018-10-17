clear
set more off

*******************************
*** SET WORKING DIRECTORIES ***
*******************************

	if "`c(username)'" == "dpatel" | "`c(username)'" == "devpatel" {
		global root "C:/Users/`c(username)'/Dropbox/Convergence"
	}
	if "`c(username)'" == "Justin"  {
		global root "/Users/Justin/Dropbox/Convergence"
	}
	global input "$root/INPUT"
	global output "$root/OUTPUT"
	global dofiles "$root/CODE"
	global paper "$root/PAPER"
	global figures "$paper/Figures"
	global tables "$paper/Tables"
	global datasets pwt mad wdi

	do "$dofiles/01 Prepare Data.do"
	do "$dofiles/02 Beta Convergence.do"
	do "$dofiles/02 Growth graphs.do"
	do "$dofiles/02 Growth sum stats.do"
exit
