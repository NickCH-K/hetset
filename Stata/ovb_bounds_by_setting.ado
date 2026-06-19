*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)
*! Requires: -sensemakr- (SSC)

program define ovb_bounds_by_setting, rclass
	version 14

	syntax varlist(min=2 numeric ts fv) [if] [in], ///
		SETting(varname)                           ///
		TREATment(varname numeric)                 ///
		BENCHmark(varlist numeric ts fv)           ///
		[ KD(numlist max=1 >0)                     ///
		  KY(numlist max=1 >0)                     ///
		  Verbose ]

	* check that sensemakr is installed
	capture which sensemakr
	if (_rc) {
		display as error "ovb_bounds_by_setting requires the {bf:sensemakr} package."
		display as error `"Install it with: {stata "ssc install sensemakr"}"'
		exit 111
	}

	* kd defaults to 1, ky defaults to kd (as in the R package)
	if ("`kd'" == "") local kd 1
	if ("`ky'" == "") local ky `kd'

	* the treatment must be one of the regressors
	gettoken depvar rhs : varlist
	if (!`: list treatment in rhs') {
		display as error "the treatment() variable `treatment' must appear among the regressors in {it:varlist}"
		exit 198
	}
	if ("`depvar'" == "`treatment'") {
		display as error "the treatment() variable cannot be the dependent variable"
		exit 198
	}

	marksample touse, novarlist
	markout `touse' `setting', strok

	quietly levelsof `setting' if `touse', local(levels)
	local nlevels : word count `levels'
	if (`nlevels' < 2) {
		display as error "setting() variable `setting' must take at least two values in the estimation sample"
		exit 198
	}

	* single benchmark covariate -> benchmark(); several -> grouped benchmark
	* (mirrors the R package, which always benchmarks the covariates as one
	*  group named 'Total' via sensemakr::ovb_bounds)
	local nbench : word count `benchmark'
	if (`nbench' == 1) local benchopt benchmark(`benchmark')
	else               local benchopt gbenchmark(`benchmark') gname(Total)

	* is the setting variable string or numeric?
	capture confirm string variable `setting'
	local isstring = (_rc == 0)

	* hold the user's current e() results; restored on exit
	tempname ehold
	capture _estimates hold `ehold', restore

	tempname B row eb
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

		capture sensemakr `varlist' if `touse' & `cond', ///
			treat(`treatment') `benchopt' kd(`kd') ky(`ky') suppress

		if (_rc) {
			local srrc = _rc
			display as error `"warning: bounds estimation failed for setting: `dispname'"'
			* Echo sensemakr's own error message by re-running noisily. The most
			* common failure is "Impossible value. Try a lower kd and/or ky":
			* this happens when the benchmark covariate(s) are too strong for the
			* chosen kd()/ky(), so the implied confounder R2 exceeds 1.  (A
			* command run under -capture- alone prints to neither screen nor log,
			* so a re-run is the only way to surface the underlying message.)
			display as text "{p 2 6 2}Re-running sensemakr for this setting to show its message:{p_end}"
			capture noisily sensemakr `varlist' if `touse' & `cond', ///
				treat(`treatment') `benchopt' kd(`kd') ky(`ky') suppress
			display as text "{p 2 6 2}If the message above is an {bf:Impossible value} (or an implied R2 greater than 1), the benchmark covariate(s) are too strong relative to kd(`kd') ky(`ky') -- a common sensemakr error. Re-run this setting with a smaller kd() and/or ky().{p_end}"
			matrix `row' = (1, `kd', `ky', ., ., ., ., ., ., ., ., ., ., ., .)
			local anyfailed = 1
		}
		else {
			matrix `eb' = e(bounds)
			local orig = e(treat_coef)
			local adj  = `eb'[1,5]
			local lpb  = `orig' - abs(`orig' - `adj')
			local upb  = `orig' + abs(`orig' - `adj')
			matrix `row' = (0, `eb'[1,1], `eb'[1,2], `eb'[1,3], `eb'[1,4], ///
				`adj', `eb'[1,6], `eb'[1,7], `eb'[1,8], `eb'[1,9],         ///
				`orig', `lpb', `upb', `orig' - `lpb', `orig' - `upb')
		}
		matrix `B' = nullmat(`B') \ `row'

		* keep the original label, and a sanitized version for matrix rownames
		local settingnames `"`settingnames' `"`dispname'"'"'
		hetset_sanitize, label(`"`dispname'"')
		local sname `r(name)'
		while (`: list sname in rownames') {
			local sname = substr("`sname'", 1, 27) + "_`i'"
		}
		local rownames `rownames' `sname'
	}

	matrix rownames `B' = `rownames'
	matrix colnames `B' = failed kd ky r2dz_x r2yz_dx                ///
		adjusted_estimate adjusted_se adjusted_t                     ///
		adjusted_lower_CI adjusted_upper_CI                          ///
		original_estimate lower_plausible_bound upper_plausible_bound ///
		lower_nu upper_nu

	* ----- display -----
	display as text ""
	display as text "Partial identification bounds by setting"
	display as text "  treatment: {res:`treatment'}   benchmark covariates: {res:`benchmark'}"
	display as text "  kd = {res:`kd'}   ky = {res:`ky'}"
	display as text ""
	display as text %-22s "Setting" %12s "Original" %12s "Adjusted" %12s "Lower" %12s "Upper"
	display as text %-22s ""        %12s "estimate" %12s "estimate" %12s "plausible" %12s "plausible"
	display as text "{hline 70}"
	forvalues k = 1/`i' {
		local dn : word `k' of `settingnames'
		local dn = abbrev(`"`dn'"', 21)
		if (`B'[`k',1] == 1) {
			display as text %-22s `"`dn'"' as error "   estimation failed"
			continue
		}
		display as text %-22s `"`dn'"' as result    ///
			%12.4f `B'[`k',11] %12.4f `B'[`k',6]    ///
			%12.4f `B'[`k',12] %12.4f `B'[`k',13]
	}
	display as text "{hline 70}"
	display as text "Full results returned in {res:r(bounds)}; pass it to {help build_bounds}."
	if (`anyfailed') display as error "warning: estimation failed in at least one setting"

	* ----- returns -----
	return scalar n_settings = `i'
	return scalar kd = `kd'
	return scalar ky = `ky'
	return local treatment `treatment'
	return local setting `setting'
	return local settings `"`settingnames'"'
	return matrix bounds = `B'
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
