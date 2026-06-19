*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)

program define supershort_rho_bounds_proposal, rclass
	version 14

	syntax varlist(min=2 numeric ts fv) [if] [in], ///
		SETting(varname)                           ///
		TREATment(varname numeric)                 ///
		[ SHORTer(varlist numeric ts fv)           ///
		  USENEGative                              ///
		  minimum_bound(numlist max=1 >1)          ///
		  maximum_bound(numlist max=1 >1)          ///
		  ORder(string asis)                       ///
		  Verbose ]

	* the treatment must be one of the regressors in the full model
	gettoken depvar rhs : varlist
	if (!`: list treatment in rhs') {
		display as error "the treatment() variable `treatment' must appear among the regressors in {it:varlist}"
		exit 198
	}

	* the super-short model defaults to the treatment alone
	if ("`shorter'" == "") local shorter `treatment'
	if (!`: list treatment in shorter') {
		display as error "the treatment() variable `treatment' must appear in shorter()"
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

	capture confirm string variable `setting'
	local isstring = (_rc == 0)

	* ----- collect display names and sanitized names, in levelsof order -----
	local settingnames
	local snames
	local i = 0
	foreach lvl of local levels {
		local ++i
		if (`isstring') local dispname `"`lvl'"'
		else            local dispname : label (`setting') `lvl'
		local settingnames `"`settingnames' `"`dispname'"'"'
		hetset_sanitize, label(`"`dispname'"')
		local sname `r(name)'
		while (`: list sname in snames') {
			local sname = substr("`sname'", 1, 27) + "_`i'"
		}
		local snames `snames' `sname'
	}

	* ----- settings order -----
	if (`"`order'"' == "") {
		local ordnames `snames'
	}
	else {
		local ordnames
		local rest `"`order'"'
		while (`"`rest'"' != "") {
			gettoken tok rest : rest
			hetset_sanitize, label(`"`tok'"')
			local sname `r(name)'
			if (`: list sname in ordnames') {
				display as error `"duplicate setting in order(): `tok'"'
				exit 198
			}
			local ordnames `ordnames' `sname'
		}
		local miss1 : list snames - ordnames
		local miss2 : list ordnames - snames
		if (`"`miss1'"' != "" | `"`miss2'"' != "") {
			display as error "order() must contain all of the values of the setting variable and no more"
			if (`"`miss1'"' != "") display as error "  missing from order(): `miss1'"
			if (`"`miss2'"' != "") display as error "  not found in the data: `miss2'"
			exit 198
		}
	}
	local K : word count `ordnames'

	* hold the user's current e() results; restored on exit
	tempname ehold
	capture _estimates hold `ehold', restore

	* ----- estimate the bias change (full minus super-short) per setting -----
	tempname D
	matrix `D' = J(`K', 1, .)
	if ("`verbose'" != "") display as text "Estimating full and super-short models by setting..."
	local i = 0
	foreach lvl of local levels {
		local ++i
		if (`isstring') local cond `"`setting' == `"`lvl'"'"'
		else            local cond `"`setting' == `lvl'"'
		local sname : word `i' of `snames'
		local pos : list posof "`sname'" in ordnames

		quietly regress `varlist' if `touse' & `cond'
		local eff_s = _b[`treatment']
		quietly regress `depvar' `shorter' if `touse' & `cond'
		local eff_ss = _b[`treatment']
		matrix `D'[`pos', 1] = `eff_s' - `eff_ss'

		if ("`verbose'" != "") {
			local dn : word `i' of `settingnames'
			display as text `"  `dn': full = "' as result %9.0g `eff_s' ///
				as text " super-short = " as result %9.0g `eff_ss'
		}
	}

	* ----- pairwise rho bounds -----
	tempname RM TAB
	matrix `RM' = J(`K', `K', .)
	local npairs = `K' * (`K' - 1) / 2
	matrix `TAB' = J(`npairs', 2, .)
	local tabnames
	local p = 0
	forvalues i = 1/`=`K'-1' {
		local sa : word `i' of `ordnames'
		local diff_a = `D'[`i', 1]
		forvalues j = `=`i'+1'/`K' {
			local sb : word `j' of `ordnames'
			local diff_b = `D'[`j', 1]
			local ++p

			local rho_low = .
			local rho_high = .
			if ("`usenegative'" != "" | sign(`diff_a') == sign(`diff_b')) {
				local r1 = .
				local r2 = .
				if (`diff_b' != 0) local r1 = `diff_a'/`diff_b'
				if (`diff_a' != 0) local r2 = `diff_b'/`diff_a'
				if (!missing(`r1') & !missing(`r2')) {
					local rho_low  = min(`r1', `r2')
					local rho_high = max(`r1', `r2')
				}
				else if (!missing(`r1') | !missing(`r2')) {
					* one ratio is infinite: keep the finite one as the
					* lower bound and leave the upper bound unrestricted
					local rho_low = min(`r1', `r2')
				}
			}

			* floor / ceiling
			if ("`minimum_bound'" != "" & !missing(`rho_low')) {
				if (`rho_low' < `minimum_bound') local rho_low = `minimum_bound'
			}
			if ("`maximum_bound'" != "" & !missing(`rho_high')) {
				if (`rho_high' > `maximum_bound') local rho_high = `maximum_bound'
			}

			matrix `RM'[`i', `j'] = `rho_high'
			matrix `RM'[`j', `i'] = `rho_low'
			matrix `TAB'[`p', 1] = `rho_low'
			matrix `TAB'[`p', 2] = `rho_high'
			local pname = substr("`sa'", 1, 14) + "_v_" + substr("`sb'", 1, 14)
			local tabnames `tabnames' `pname'
		}
	}
	matrix rownames `RM' = `ordnames'
	matrix colnames `RM' = `ordnames'
	matrix rownames `TAB' = `tabnames'
	matrix colnames `TAB' = rho_low rho_high

	* ----- display -----
	display as text ""
	display as text "Proposed rho bounds from super-short model comparison"
	display as text "  full model regressors: {res:`rhs'}"
	display as text "  super-short model regressors: {res:`shorter'}"
	display as text ""
	display as text "Pairwise proposed bounds (missing = uninformative / unrestricted):"
	matlist `TAB', format(%10.4f)
	display as text ""
	display as text "Rho bounds matrix (upper bounds above the diagonal, lower bounds below):"
	matlist `RM', format(%10.4f)
	display as text ""
	display as text "Matrix returned in {res:r(rho_bounds)}; pass it to the rho() option of {help build_bounds}."

	* ----- returns -----
	return scalar n_settings = `K'
	return local settings `ordnames'
	return matrix table = `TAB'
	return matrix rho_bounds = `RM'
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
