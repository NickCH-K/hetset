{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "custom_ovb_bounds_by_setting##syntax"}{...}
{viewerjumpto "Description" "custom_ovb_bounds_by_setting##description"}{...}
{viewerjumpto "Options" "custom_ovb_bounds_by_setting##options"}{...}
{viewerjumpto "Examples" "custom_ovb_bounds_by_setting##examples"}{...}
{viewerjumpto "Stored results" "custom_ovb_bounds_by_setting##results"}{...}
{title:Title}

{phang}
{bf:custom_ovb_bounds_by_setting} {hline 2} Create a custom bounds table


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:custom_ovb_bounds_by_setting}{cmd:,}
{opt set:ting(namelist)}
{opt original_estimate(numlist)}
{opt lower_plausible_bound(numlist)}
{opt upper_plausible_bound(numlist)}

{pstd}
All four options are required and must contain the same number of elements.
Setting names containing spaces must be enclosed in quotes.


{marker description}{...}
{title:Description}

{pstd}
{cmd:custom_ovb_bounds_by_setting} is a convenience command for
constructing a bounds table with the correct column names and structure to
use as input to {helpb build_bounds}, when partial identification bounds
come from a source other than {helpb ovb_bounds_by_setting} (e.g. manual
calibration, a different sensitivity framework, or a bootstrapped
interval).

{pstd}
The returned matrix has the same format as the {cmd:r(bounds)} output of
{helpb ovb_bounds_by_setting} and can be passed directly to the
{opt bounds()} option of {helpb build_bounds}.


{marker options}{...}
{title:Options}

{phang}
{opt setting(namelist)} provides the setting names, one per setting.  Each
value must be unique.

{phang}
{opt original_estimate(numlist)} provides the point estimates for the
treatment effect in each setting.

{phang}
{opt lower_plausible_bound(numlist)} provides the lower plausible bounds
for the treatment effect in each setting.

{phang}
{opt upper_plausible_bound(numlist)} provides the upper plausible bounds
for the treatment effect in each setting.


{marker examples}{...}
{title:Examples}

{pstd}Manually specified bounds{p_end}
{phang2}{cmd:. custom_ovb_bounds_by_setting, setting(Control Treated) original_estimate(0.4 0.6) lower_plausible_bound(0.2 0.4) upper_plausible_bound(0.6 0.8)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(2)}{p_end}

{pstd}Setting names with spaces{p_end}
{phang2}{cmd:. custom_ovb_bounds_by_setting, setting("Group A" "Group B") original_estimate(0.4 0.6) lower_plausible_bound(0.2 0.4) upper_plausible_bound(0.6 0.8)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:custom_ovb_bounds_by_setting} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(settings)}}setting names, in row order of {cmd:r(bounds)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(bounds)}}one row per setting with columns {cmd:failed},
{cmd:original_estimate}, {cmd:lower_plausible_bound},
{cmd:upper_plausible_bound}, {cmd:lower_nu}, {cmd:upper_nu}{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb ovb_bounds_by_setting}, {helpb build_bounds}
{p_end}
