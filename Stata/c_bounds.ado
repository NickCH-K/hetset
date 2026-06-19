*! version 0.1.0  10jun2026  Nick Huntington-Klein (nhuntington-klein@seattleu.edu)
*! Part of the -hetset- package (Huntington-Klein 2026, arXiv:2605.25483)

program define c_bounds, rclass
	version 14

	syntax , b_lower(numlist max=1) b_upper(numlist max=1) ///
		rho_upper(numlist max=1) [ rho_lower(numlist max=1) ]

	if ("`b_lower'" == "" | "`b_upper'" == "" | "`rho_upper'" == "") {
		display as error "b_lower(), b_upper(), and rho_upper() are all required"
		exit 198
	}
	if (`b_lower' > `b_upper') {
		display as error "b_lower() must be less than or equal to b_upper()"
		exit 198
	}

	* rho_lower defaults to 1/rho_upper, a common choice that ensures a
	* symmetrical bound on the ratio
	if ("`rho_lower'" == "") {
		if (`rho_upper' == 0) {
			display as error "rho_upper() cannot be 0 when rho_lower() is not specified"
			exit 198
		}
		local rho_lower = 1/`rho_upper'
	}

	local c1 = (`rho_lower' - 1)*`b_lower'
	local c2 = (`rho_upper' - 1)*`b_lower'
	local c3 = (`rho_lower' - 1)*`b_upper'
	local c4 = (`rho_upper' - 1)*`b_upper'

	tempname CS
	matrix `CS' = (`c1', `c2', `c3', `c4')
	matrix colnames `CS' = c1 c2 c3 c4
	matrix rownames `CS' = C_set

	local lo = min(`c1', `c2', `c3', `c4')
	local hi = max(`c1', `c2', `c3', `c4')

	display as text ""
	display as text "C set bounding the difference between two effects (Huntington-Klein 2026)"
	display as text "  nu_b bounds: [" as result %9.0g `b_lower' as text ", " ///
		as result %9.0g `b_upper' as text "]   rho bounds: [" ///
		as result %9.0g `rho_lower' as text ", " as result %9.0g `rho_upper' as text "]"
	display as text ""
	display as text "  C set range: [" as result %9.0g `lo' as text ", " ///
		as result %9.0g `hi' as text "]"
	display as text ""
	display as text "Range returned in {res:r(lower)} and {res:r(upper)};"
	display as text "the full set of four corner values in {res:r(cset)}."

	return scalar lower = `lo'
	return scalar upper = `hi'
	return matrix cset = `CS'
end
