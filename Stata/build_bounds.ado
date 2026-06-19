*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)

program define build_bounds, rclass
	version 14

	syntax , BOunds(name) RHO(string) [ ORder(string asis) noDISplay ]

	confirm matrix `bounds'
	local K = rowsof(`bounds')
	if (`K' < 2) {
		display as error "bounds() must contain at least two settings (rows)"
		exit 198
	}
	local rnames : rownames `bounds'

	* locate the required columns by name
	local cnames : colnames `bounds'
	local c_est : list posof "original_estimate" in cnames
	local c_lpb : list posof "lower_plausible_bound" in cnames
	local c_upb : list posof "upper_plausible_bound" in cnames
	if (`c_est' == 0 | `c_lpb' == 0 | `c_upb' == 0) {
		display as error "bounds() must have columns named original_estimate, lower_plausible_bound, and upper_plausible_bound"
		display as error "(such a matrix is returned by ovb_bounds_by_setting or custom_ovb_bounds_by_setting)"
		exit 198
	}

	* ----- rho: either an existing matrix or a single positive value -----
	tempname RB
	capture confirm matrix `rho'
	if (_rc == 0) {
		matrix `RB' = `rho'
	}
	else {
		capture confirm number `rho'
		if (_rc) {
			display as error "rho() must be either the name of a matrix or a single real value"
			exit 198
		}
		matrix `RB' = J(`K', `K', `rho')
		if (`rho' != 0) {
			forvalues i = 2/`K' {
				forvalues j = 1/`=`i'-1' {
					matrix `RB'[`i',`j'] = 1/`rho'
				}
			}
		}
	}

	* ----- settings order -----
	if (`"`order'"' == "") {
		local ordnames `rnames'
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
	}
	local miss1 : list rnames - ordnames
	local miss2 : list ordnames - rnames
	if (`"`miss1'"' != "") {
		display as error "the following settings are in bounds() but not in order(): `miss1'"
		exit 198
	}
	if (`"`miss2'"' != "") {
		display as error "the following settings are in order() but not in bounds(): `miss2'"
		exit 198
	}

	if (rowsof(`RB') != colsof(`RB') | rowsof(`RB') != `K') {
		display as error "rho() must be a square matrix with dimensions equal to the number of settings (`K')"
		exit 198
	}

	* ----- univariate bounds, in settings order -----
	* columns: estimate, lower, upper, lower_nu (= est - upper), upper_nu (= est - lower)
	tempname U P
	matrix `U' = J(`K', 5, .)
	local k = 0
	foreach s of local ordnames {
		local ++k
		local rpos : list posof "`s'" in rnames
		matrix `U'[`k',1] = `bounds'[`rpos', `c_est']
		matrix `U'[`k',2] = `bounds'[`rpos', `c_lpb']
		matrix `U'[`k',3] = `bounds'[`rpos', `c_upb']
		if (missing(`U'[`k',1]) | missing(`U'[`k',2]) | missing(`U'[`k',3])) {
			display as error "missing estimate or plausible bounds for setting `s' (did estimation fail for this setting?)"
			exit 416
		}
		matrix `U'[`k',4] = `U'[`k',1] - `U'[`k',3]
		matrix `U'[`k',5] = `U'[`k',1] - `U'[`k',2]
	}
	matrix rownames `U' = `ordnames'
	matrix colnames `U' = estimate lower upper lower_nu upper_nu

	* ----- are all sub-diagonal rho values zero (or missing)? -----
	* if so, lower rho bounds are set to the inverse of the upper bounds
	local subzero = 1
	forvalues i = 2/`K' {
		forvalues j = 1/`=`i'-1' {
			local v = `RB'[`i',`j']
			if (!missing(`v') & `v' != 0) local subzero = 0
		}
	}

	* ----- paired bounds -----
	* P[i,j] (i<j) holds the upper bound on nu_i - nu_j; P[j,i] the lower bound.
	* missing = no restriction on that pair.
	matrix `P' = J(`K', `K', .)
	forvalues i = 1/`=`K'-1' {
		forvalues j = `=`i'+1'/`K' {
			local ru = `RB'[`i',`j']
			if (missing(`ru') | `ru' == 0) continue
			if (`subzero') local rl = 1/`ru'
			else {
				local rl = `RB'[`j',`i']
				if (missing(`rl')) local rl = 0
			}
			local bl = `U'[`j',4]
			local bu = `U'[`j',5]
			local c1 = (`rl' - 1)*`bl'
			local c2 = (`ru' - 1)*`bl'
			local c3 = (`rl' - 1)*`bu'
			local c4 = (`ru' - 1)*`bu'
			matrix `P'[`i',`j'] = max(`c1', `c2', `c3', `c4')
			matrix `P'[`j',`i'] = min(`c1', `c2', `c3', `c4')
		}
	}
	matrix rownames `P' = `ordnames'
	matrix colnames `P' = `ordnames'

	* ----- display -----
	if ("`display'" != "nodisplay") {
		display as text ""
		display as text "Univariate plausibility bounds by setting:"
		matlist `U', format(%10.4f)
		display as text ""
		display as text "Paired bounds on bias differences (nu_row - nu_column):"
		display as text "  element [i,j] with i above the diagonal = upper bound; [j,i] = lower bound"
		display as text "  missing (.) = no restriction on that pair"
		matlist `P', format(%10.4f)
		display as text ""
		display as text "Full bounds set returned in {res:r(univariate)} and {res:r(paired)};"
		display as text "pass both to {help identified_set_exists} or {help univariate_bounds_table}."
	}

	* ----- returns -----
	return scalar n_settings = `K'
	return local settings `ordnames'
	return matrix univariate = `U'
	return matrix paired = `P'
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
