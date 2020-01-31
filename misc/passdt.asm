%macro passdef 0-*.nolist
%rep %0
 %ifdef _%1
  %warning using define -D_%1=_%1
 %else
  %warning using define -U_%1
 %endif
 %rotate 1
%endrep
%endmacro
passdef _DATE__, _TIME__, _DATE_NUM__, _TIME_NUM__
passdef _UTC_DATE__, _UTC_TIME__, _UTC_DATE_NUM__, _UTC_TIME_NUM__
passdef _POSIX_TIME__
