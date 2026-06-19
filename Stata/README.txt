hetset for Stata, version 0.1.0
================================

Partial identification of heterogeneous treatment effects across settings,
as in Huntington-Klein (2026), https://arxiv.org/abs/2605.25483.

This is the Stata port of the R package "hetset". Command names match the
R package's function names to make documentation transferable between the
two.


Files in this folder
--------------------

Program files (installed on the ado-path):
    ovb_bounds_by_setting.ado / .sthlp
    custom_ovb_bounds_by_setting.ado / .sthlp
    supershort_rho_bounds_proposal.ado / .sthlp
    build_bounds.ado / .sthlp
    identified_set_exists.ado / .sthlp
    univariate_bounds_table.ado / .sthlp
    estimate_het_effects.ado / .sthlp
    c_bounds.ado / .sthlp
    hetset.sthlp           (package overview help)
    close_college.sthlp    (dataset documentation)

Ancillary files (downloaded to the working directory with
"ssc install hetset, all" or "net get hetset"):
    close_college.dta      (example data; Card 1995 via causaldata, with
                            the blacksouth setting variable added)
    hetset_examples.do     (worked examples mirroring the R documentation)

Installation control files:
    stata.toc              (net-from table of contents)
    hetset.pkg            (package manifest for net install / net get)

Not part of the SSC submission:
    README.txt             (this file)


Installing
----------

From a local copy or a URL, point Stata's -net- at this folder:

    net from "C:/Users/nickc/OneDrive/Documents/hetset/Stata2"
    net install hetset
    net get hetset            // grabs close_college.dta and hetset_examples.do

(use a file:// URL or a forward-slash path). Once the package is on SSC,
end users instead run:

    ssc install hetset, all   // , all also grabs the ancillary files
    ssc install sensemakr     // required dependency


Suggested SSC package metadata
------------------------------

Package name: hetset

Title line: 'HETSET': module for partial identification of heterogeneous
treatment effects across settings

Abstract: hetset implements the partial identification framework of
Huntington-Klein (2026, arXiv:2605.25483) for causal effects that vary
across settings (subgroups). Effects are estimated separately by setting,
with omitted-variable-bias plausibility intervals from sensemakr (Cinelli,
Ferwerda, and Hazlett). Researchers then bound rho, the proportional
relationship between the bias in one setting and another, and hetset uses
linear programming to check whether an identified set of effects exists and
to report the per-setting bounds implied by all restrictions jointly. A
Stata port of the R package of the same name.

Dependency to declare in the submission email: requires the sensemakr
package from SSC (Cinelli, Ferwerda, and Hazlett, s458773) for the
ovb_bounds_by_setting command.

Stata version requirements: identified_set_exists and
univariate_bounds_table require Stata 16 (they use the Mata
LinearProgram() class). All other commands require Stata 14.


Notes on the port (differences from the R package)
--------------------------------------------------

- Estimation is via -regress- (the R package uses fixest::feols). The
  model is given as "depvar indepvars" rather than as a model-call string.
- The R workflow passes data frames and lists between functions; the Stata
  workflow passes matrices: each command stores its output in r() and the
  next command takes the matrix names as options.
- Setting labels are sanitized for use as matrix row/column names (e.g.
  "Black and South" -> "Black_and_South"). Commands accept either form in
  order(), checkonly(), and pin().
- Stata matrices cannot store infinity, so unrestricted bounds are stored
  as missing (.) rather than +/-Inf. build_bounds and the LP commands
  treat missing pair bounds as unrestricted.
- The LP solver is Mata's LinearProgram() class (the R package uses Rglpk,
  the Python port uses scipy's HiGHS). Variables are unbounded, matching
  the Python port.
- ovb_bounds_by_setting_dml() is not ported; it depends on the R-only
  dml.sensemakr package.
- kd() and ky() take single values here. To examine several confounder
  strengths, run ovb_bounds_by_setting once per value.

Why the dataset ships with the package: SSC submission guidance
(repec.org/bocode/s/sscsubmit.html) explicitly welcomes a sample dataset
as part of a complete submission, and the Stata sensemakr package follows
the same pattern with darfur.dta. Shipping the file also avoids examples
that depend on web downloads at run time, and the copy here includes the
blacksouth variable, which the causaldata version of close_college.dta
does not. The help files additionally show how to construct the data via
the causaldata package (SSC) for users who prefer that route.


Submission checklist (sscsubmit.html, revision of 2 May 2022)
-------------------------------------------------------------

[x] Every ado-file has a "version n.n" statement (14 or 16; see above)
[x] Help files are .sthlp (version >= 10)
[x] Command names are strictly lower case, no reserved graphics words
[x] Programs written to work under "set varabbrev off"
[x] Dependency on another SSC item (sensemakr) identified above
[ ] Zip this folder (without README.txt) and email to the SSC maintainer
    (Kit Baum, baum@bc.edu), indicating it is a new package and including
    the title line, abstract, and dependency note above
[ ] After it goes live, announce on Statalist

Author: Nick Huntington-Klein, Seattle University,
nhuntington-klein@seattleu.edu
