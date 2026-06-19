*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)
*! Requires Stata 16 or later (uses the Mata LinearProgram() class)

program define univariate_bounds_table, rclass
	version 16

	syntax , UNIvariate(name) PAIRed(name) [ PIN(string asis) noDISplay ]

	confirm matrix `univariate'
	confirm matrix `paired'
	local K = rowsof(`univariate')
	local rnames : rownames `univariate'
	if (rowsof(`paired') != `K' | colsof(`paired') != `K') {
		display as error "paired() must be a `K' x `K' matrix matching the rows of univariate()"
		exit 198
	}

	* working copy of the univariate bounds, so pinning does not alter the input
	tempname W
	matrix `W' = `univariate'

	* ----- parse pin(): elements of the form  setting=value  -----
	* value may be a number, or lower / upper / original
	if (`"`pin'"' != "") {
		local rest `"`pin'"'
		while (`"`rest'"' != "") {
			gettoken tok rest : rest
			local eq = strpos(`"`tok'"', "=")
			if (`eq' == 0) {
				display as error `"pin() elements must have the form setting=value (got: `tok')"'
				exit 198
			}
			local pname = strtrim(substr(`"`tok'"', 1, `eq' - 1))
			local pval  = strtrim(substr(`"`tok'"', `eq' + 1, .))
			hetset_sanitize, label(`"`pname'"')
			local sname `r(name)'
			local pos : list posof "`sname'" in rnames
			if (`pos' == 0) {
				display as error `"setting `pname' in pin() not found in univariate()"'
				exit 198
			}
			if ("`pval'" == "lower")         local v = `univariate'[`pos', 2]
			else if ("`pval'" == "upper")    local v = `univariate'[`pos', 3]
			else if ("`pval'" == "original") local v = `univariate'[`pos', 1]
			else {
				capture confirm number `pval'
				if (_rc) {
					display as error `"pin() value for setting `pname' must be a number, lower, upper, or original"'
					exit 198
				}
				local v = `pval'
			}
			matrix `W'[`pos', 2] = `v'
			matrix `W'[`pos', 3] = `v'
		}
	}

	* ----- build constraints from the (possibly pinned) bounds -----
	tempname A b c sol
	hetset_lp_setup, univariate(`W') paired(`paired') ///
		settings(`rnames') aname(`A') bname(`b')

	* ----- for each setting, minimize and maximize its effect -----
	tempname T
	matrix `T' = J(`K', 7, .)
	forvalues s = 1/`K' {
		matrix `c' = J(1, `K', 0)
		matrix `c'[1, `s'] = 1

		hetset_lp_solve, a(`A') b(`b') c(`c')
		if (r(errorcode) == 1) {
			display as error "no identified set satisfying all bounds exists, so no bounds table can be computed"
			display as error "run {help identified_set_exists} with the checkonly() option to diagnose"
			exit 430
		}
		else if (r(errorcode) != 0) {
			display as error "the linear programming solver failed (Mata LinearProgram() error code " r(errorcode) ")"
			exit 430
		}
		matrix `sol' = r(solution)
		local slv_low = `sol'[1, `s']

		hetset_lp_solve, a(`A') b(`b') c(`c') maximize
		if (r(errorcode) != 0) {
			display as error "the linear programming solver failed (Mata LinearProgram() error code " r(errorcode) ")"
			exit 430
		}
		matrix `sol' = r(solution)
		local slv_up = `sol'[1, `s']

		local est = `univariate'[`s', 1]
		matrix `T'[`s',1] = `est'
		matrix `T'[`s',4] = `est' - `slv_up'     // lower_nu_bound
		matrix `T'[`s',5] = `est' - `slv_low'    // upper_nu_bound
		matrix `T'[`s',2] = `est' - `T'[`s',5]   // lower_bound
		matrix `T'[`s',3] = `est' - `T'[`s',4]   // upper_bound
		matrix `T'[`s',6] = `univariate'[`s', 2] // original_lower_bound
		matrix `T'[`s',7] = `univariate'[`s', 3] // original_upper_bound
	}
	matrix rownames `T' = `rnames'
	matrix colnames `T' = estimate lower_bound upper_bound ///
		lower_nu_bound upper_nu_bound original_lower_bound original_upper_bound

	* ----- display -----
	if ("`display'" != "nodisplay") {
		display as text ""
		display as text "Univariate bounds table"
		display as text "  Widest possible bounds for each setting consistent with all assumptions,"
		display as text "  taking each setting one at a time. The joint identified set is narrower:"
		display as text "  not all combinations of values within these bounds are jointly feasible."
		display as text ""
		matlist `T'[1..., 1..3], format(%10.4f)
		display as text ""
		display as text "Full table (including nu bounds and the original input bounds)"
		display as text "returned in {res:r(table)}."
	}

	* ----- returns -----
	return scalar n_settings = `K'
	return local settings `rnames'
	return matrix table = `T'
end

* ----------------------------------------------------------------------
* private: build the inequality constraints A*x <= b implied by the
* univariate and paired bounds, restricted to the listed settings
* ----------------------------------------------------------------------
program define hetset_lp_setup
	version 16
	syntax , UNIvariate(name) PAIRed(name) SETtings(string) ANAME(name) BNAME(name)

	local rnames : rownames `univariate'
	local m : word count `settings'

	tempname row
	* univariate restrictions: lower <= theta_k <= upper
	forvalues k = 1/`m' {
		local s : word `k' of `settings'
		local pos : list posof "`s'" in rnames
		local low = `univariate'[`pos', 2]
		local upp = `univariate'[`pos', 3]
		if (!missing(`upp')) {
			matrix `row' = J(1, `m', 0)
			matrix `row'[1, `k'] = 1
			matrix `aname' = nullmat(`aname') \ `row'
			matrix `bname' = nullmat(`bname') \ (`upp')
		}
		if (!missing(`low')) {
			matrix `row' = J(1, `m', 0)
			matrix `row'[1, `k'] = -1
			matrix `aname' = nullmat(`aname') \ `row'
			matrix `bname' = nullmat(`bname') \ (-`low')
		}
	}

	* pair restrictions: theta_k - theta_l within est_k - est_l + [d_lower, d_upper]
	forvalues k = 1/`=`m'-1' {
		local sk : word `k' of `settings'
		local posk : list posof "`sk'" in rnames
		forvalues l = `=`k'+1'/`m' {
			local sl : word `l' of `settings'
			local posl : list posof "`sl'" in rnames
			local dup = `paired'[`posk', `posl']
			local dlo = `paired'[`posl', `posk']
			local estk = `univariate'[`posk', 1]
			local estl = `univariate'[`posl', 1]
			if (!missing(`dup')) {
				matrix `row' = J(1, `m', 0)
				matrix `row'[1, `k'] = 1
				matrix `row'[1, `l'] = -1
				matrix `aname' = nullmat(`aname') \ `row'
				matrix `bname' = nullmat(`bname') \ (`estk' - `estl' + `dup')
			}
			if (!missing(`dlo')) {
				matrix `row' = J(1, `m', 0)
				matrix `row'[1, `k'] = -1
				matrix `row'[1, `l'] = 1
				matrix `aname' = nullmat(`aname') \ `row'
				matrix `bname' = nullmat(`bname') \ (-(`estk' - `estl' + `dlo'))
			}
		}
	}
end

* ----------------------------------------------------------------------
* private: solve  min/max c*x  s.t.  A*x <= b  with free variables,
* using the Mata LinearProgram() class (Stata 16+).
* Mata work is done with inline statements (no Mata function definitions)
* so that it survives -mata clear- issued by other packages on load.
* ----------------------------------------------------------------------
program define hetset_lp_solve, rclass
	version 16
	syntax , a(name) b(name) c(name) [ MAXimize ]

	local sense = cond("`maximize'" == "", "min", "max")

	capture mata: mata drop __hetset_q
	capture mata: mata drop __hetset_v
	mata: __hetset_q = LinearProgram()
	mata: __hetset_q.setCoefficients(st_matrix("`c'"))
	mata: __hetset_q.setMaxOrMin("`sense'")
	mata: __hetset_q.setInequality(st_matrix("`a'"), st_matrix("`b'"))
	capture mata: __hetset_v = __hetset_q.optimize()

	tempname ec
	mata: st_numscalar("`ec'", __hetset_q.errorcode())
	return scalar errorcode = `ec'
	if (`ec' == 0) {
		tempname sol
		mata: st_matrix("`sol'", __hetset_q.parameters())
		return matrix solution = `sol'
	}
	capture mata: mata drop __hetset_q
	capture mata: mata drop __hetset_v
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
