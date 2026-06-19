*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)

program define estimate_het_effects, rclass
	version 14

	syntax varlist(min=2 ts fv) [if] [in], ///
		SETting(varname)                   ///
		TREATment(varname numeric)         ///
		[ CMD(name)                        ///
		  CMDOPTions(string asis)          ///
		  Verbose ]

	* estimation command defaults to regress (the R package default is
	* linear regression via fixest::feols)
	if ("`cmd'" == "") local cmd regress

	gettoken depvar rhs : varlist
	if (!`: list treatment in rhs') {
		display as error "the treatment() variable `treatment' must appear among the regressors in {it:varlist}"
		exit 198
	}

	marksample touse, novarlist
	markout `touse' `setting', strok

	quietly levelsof `setting' if `touse', local(levels)
	local nlevels : word count `levels'
	if (`nlevels' < 1) {
		display as error "setting() variable `setting' has no nonmissing values in the estimation sample"
		exit 2000
	}

	capture confirm string variable `setting'
	local isstring = (_rc == 0)

	* hold the user's current e() results; restored on exit
	tempname ehold
	capture _estimates hold `ehold', restore

	tempname E row
	local settingnames
	local rownames
	local i = 0
	local anyfailed = 0

	if ("`verbose'" != "") display as text "Estimating effects by setting..."

	foreach lvl of local levels {
		local ++i
		if (`isstring') {
			local dispname `"`lvl'"'
			local cond `"`setting' == `"`lvl'"'"'
		}
		else {
			local dispname : label (`setting') `lvl'
			local cond `"`setting' == `lvl'"'
		}
		if ("`verbose'" != "") display as text `"  Running setting: `dispname'"'

		capture quietly `cmd' `varlist' if `touse' & `cond', `cmdoptions'

		* the treatment coefficient must also be extractable from e()
		local est = .
		local se  = .
		if (!_rc) {
			capture {
				local est = _b[`treatment']
				local se  = _se[`treatment']
			}
		}

		if (_rc) {
			display as error `"warning: estimation failed for setting: `dispname'"'
			matrix `row' = (1, ., ., ., ., ., ., .)
			local anyfailed = 1
		}
		else {
			local n   = e(N)
			local t = .
			local pval = .
			if (!missing(`est') & !missing(`se') & `se' > 0) {
				local t = `est'/`se'
				if (!missing(e(df_r))) local pval = 2*ttail(e(df_r), abs(`t'))
				else                   local pval = 2*(1 - normal(abs(`t')))
			}
			local r2   = cond(missing(e(r2)),   ., e(r2))
			local rmse = cond(missing(e(rmse)), ., e(rmse))
			matrix `row' = (0, `est', `se', `n', `t', `pval', `r2', `rmse')
		}
		matrix `E' = nullmat(`E') \ `row'

		local settingnames `"`settingnames' `"`dispname'"'"'
		hetset_sanitize, label(`"`dispname'"')
		local sname `r(name)'
		while (`: list sname in rownames') {
			local sname = substr("`sname'", 1, 27) + "_`i'"
		}
		local rownames `rownames' `sname'
	}

	matrix rownames `E' = `rownames'
	matrix colnames `E' = failed estimate std_error n_obs t_stat p_value r_squared rmse

	* ----- display -----
	display as text ""
	display as text "Treatment effect estimates by setting"
	display as text "  treatment: {res:`treatment'}   estimation command: {res:`cmd'}"
	display as text ""
	display as text %-22s "Setting" %12s "Estimate" %12s "Std. err." %10s "t-stat" %10s "p-value" %8s "N"
	display as text "{hline 76}"
	forvalues k = 1/`i' {
		local dn : word `k' of `settingnames'
		local dn = abbrev(`"`dn'"', 21)
		if (`E'[`k',1] == 1) {
			display as text %-22s `"`dn'"' as error "   estimation failed"
			continue
		}
		display as text %-22s `"`dn'"' as result          ///
			%12.4f `E'[`k',2] %12.4f `E'[`k',3]           ///
			%10.3f `E'[`k',5] %10.3f `E'[`k',6] %8.0f `E'[`k',4]
	}
	display as text "{hline 76}"
	display as text "Full results returned in {res:r(estimates)}."
	if (`anyfailed') display as error "warning: estimation failed in at least one setting"

	* ----- returns -----
	return scalar n_settings = `i'
	return local treatment `treatment'
	return local setting `setting'
	return local cmd `cmd'
	return local settings `"`settingnames'"'
	return matrix estimates = `E'
end

* private: turn an arbitrary setting label into a legal matrix row name
program define hetset_sanitize, rclass
	version 14
	syntax , LABel(string)
	local out ""
	local n = strlen(`"`label'"')
	forvalues i = 1/`n' {
		local c = substr(`"`label'"', `i', 1)
		if (regexm(`"`c'"', "^[A-Za-z0-9_]$")) local out `out'`c'
		else local out `out'_
	}
	if (`"`out'"' == "")             local out s
	if (regexm(`"`out'"', "^[0-9]")) local out s`out'
	local out = substr(`"`out'"', 1, 30)
	return local name `out'
end
