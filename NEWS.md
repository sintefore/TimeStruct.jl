TimeStructures release notes
===================================

Version 0.1.9 (2021-08-16)
--------------------------
* Define basic arithmetic functions for TimeProfiles (#8)

Version 0.1.8 (2021-08-04)
--------------------------
* Restructured and commented the file for improved readability (#7)
* Inclusion of functions for DynamicTwoLevel and DynamicOperationalLevel (#7)
* Inclusion of DynamicStrategicLevel (#7)
* Export of all two level time structures (#7)
* Bug fixes:
    * Iterations over time structures and strategic periods result in 
      proper duration for operational periods
    * Functions next and previous now have proper durations

Version 0.1.7 (2021-06-14)
--------------------------
* Add missing exports and utilities for InvestmentModels (#6)

Version 0.1.6 (2021-06-11)
--------------------------
* Time varying duration with new DynamicTimes (experimental)(#5)
* Iterator that includes previous time period (#5)

Version 0.1.5 (2021-04-21)
--------------------------
* Indexing on StrategicPeriods for StrategicFixedProfile added (#3)
* Bugfix: Iteration on strategic periods let to wrong values in a
strategic period > 1 (#3)

Version 0.1.4 (2021-04-07)
--------------------------
* Add previous for OperationalPeriods (#1)
* Add first_operational, last_operational (#1)
* Require julia v1.6 (#1)

Version 0.1.3 (2021-03-19)
--------------------------
* Pretty print StrategicPeriods

Version 0.1.2 (2021-03-18)
--------------------------
* Allow Julia v1.5 until official release of v1.6
* Add missing export
* Pretty print OperationalPeriods
* Fix file name issue for Windows
* Disable failing tests on v1.5

Version 0.1.0 (2021-03-17)
--------------------------
* Initial version
* UniformTwoLevel time structure
* Simple profiles for input values