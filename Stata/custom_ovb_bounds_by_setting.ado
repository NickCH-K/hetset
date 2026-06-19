*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)

program define custom_ovb_bounds_by_setting, rclass
	version 14

	syntax , SETting(string asis)          ///
		original_estimate(numlist)         ///
		lower_plausible_bound(numlist)     ///
		upper_plausible_bound(numlist)

	* parse the (possibly quoted) setting labels
	local settingnames
	local rownames
	local n = 0
	local rest `"`setting'"'
	while (`"`rest'"' != "") {
		gettoken tok rest : rest
		local ++n
		local settingnames `"`settingnames' `"`tok'"'"'
		hetset_sanitize, label(`"`tok'"')
		local sname `r(name)'
		if (`: list sname in rownames') {
			display as error "duplicate values in setting(). Each setting must appear exactly once."
			exit 198
		}
		local rownames `rownames' `sname'
	}

	local n_est : word count `original_estimate'
	local n_low : word count `lower_plausible_bound'
	local n_upp : word count `upper_plausible_bound'
	if (`n_est' != `n' | `n_low' != `n' | `n_upp' != `n') {
		display as error "setting(), original_estimate(), lower_plausible_bound(), and upper_plausible_bound() must all have the same number of elements"
		exit 198
	}

	tempname B
	matrix `B' = J(`n', 6, .)
	forvalues k = 1/`n' {
		local est : word `k' of `original_estimate'
		local low : word `k' of `lower_plausible_bound'
		local upp : word `k' of `upper_plausible_bound'
		matrix `B'[`k',1] = 0
		matrix `B'[`k',2] = `est'
		matrix `B'[`k',3] = `low'
		matrix `B'[`k',4] = `upp'
		matrix `B'[`k',5] = `est' - `low'
		matrix `B'[`k',6] = `est' - `upp'
	}
	matrix rownames `B' = `rownames'
	matrix colnames `B' = failed original_estimate ///
		lower_plausible_bound upper_plausible_bound lower_nu upper_nu

	* ----- display -----
	display as text ""
	display as text "Custom partial identification bounds by setting"
	display as text ""
	display as text %-22s "Setting" %12s "Original" %12s "Lower" %12s "Upper"
	display as text %-22s ""        %12s "estimate" %12s "plausible" %12s "plausible"
	display as text "{hline 58}"
	forvalues k = 1/`n' {
		local dn : word `k' of `settingnames'
		local dn = abbrev(`"`dn'"', 21)
		display as text %-22s `"`dn'"' as result ///
			%12.4f `B'[`k',2] %12.4f `B'[`k',3] %12.4f `B'[`k',4]
	}
	display as text "{hline 58}"
	display as text "Bounds table returned in {res:r(bounds)}; pass it to {help build_bounds}."

	* ----- returns -----
	return scalar n_settings = `n'
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
