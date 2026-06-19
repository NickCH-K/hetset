*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)
*! Requires Stata 16 or later (uses the Mata LinearProgram() class)

program define identified_set_exists, rclass
	version 16

	syntax , UNIvariate(name) PAIRed(name) [ CHECKonly(string asis) SOLution ]

	confirm matrix `univariate'
	confirm matrix `paired'
	local K = rowsof(`univariate')
	local rnames : rownames `univariate'
	if (rowsof(`paired') != `K' | colsof(`paired') != `K') {
		display as error "paired() must be a `K' x `K' matrix matching the rows of univariate()"
		exit 198
	}

	* ----- which settings to check -----
	if (`"`checkonly'"' == "") {
		local chk `rnames'
	}
	else {
		local chk
		local rest `"`checkonly'"'
		while (`"`rest'"' != "") {
			gettoken tok rest : rest
			hetset_sanitize, label(`"`tok'"')
			local sname `r(name)'
			if (`: list posof "`sname'" in rnames' == 0) {
				display as error `"setting `tok' in checkonly() not found in univariate()"'
				exit 198
			}
			local chk `chk' `sname'
		}
		if (`: word count `chk'' < 2) {
			display as error "checkonly() must contain at least two settings to check joint satisfiability"
			exit 198
		}
	}

	* ----- build the LP constraints and solve with a zero objective -----
	tempname A b c
	hetset_lp_setup, univariate(`univariate') paired(`paired') ///
		settings(`chk') aname(`A') bname(`b')
	local m : word count `chk'
	matrix `c' = J(1, `m', 0)

	hetset_lp_solve, a(`A') b(`b') c(`c')
	local ec = r(errorcode)

	if (`ec' == 0) {
		display as text ""
		display as result "An identified set satisfying all bounds exists."
		return scalar exists = 1
		if ("`solution'" != "") {
			tempname sol
			matrix `sol' = r(solution)
			matrix colnames `sol' = `chk'
			matrix rownames `sol' = effect
			display as text ""
			display as text "One set of effect parameters inside the identified set:"
			matlist `sol', format(%10.4f)
			display as text ""
			display as text "IMPORTANT: this is not a {it:best} or representative solution."
			display as text "It is simply one possible point in the identified set."
			return matrix solution = `sol'
		}
	}
	else if (`ec' == 1) {
		display as text ""
		display as result "No identified set satisfying all bounds exists."
		display as text "Use checkonly() to find which settings drive the infeasibility."
		return scalar exists = 0
	}
	else {
		display as error "the linear programming solver failed (Mata LinearProgram() error code `ec')"
		exit 430
	}
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
