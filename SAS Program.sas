libname foo "/users/briancarter/onedrive/SAS/sas-r-test/data";


proc format;

value bmicat
    1 = "1. Underweight"
    2 = "2. Normal weight"
    3 = "3. Overweight"
    4 = "4. Obese"
    ;

value yesno
    0 = "0. No"
    1 = "1. Yes"
    ;

value agecat
    1 = "1. 30-39"
    2 = "2. 40-54"
    3 = "3. 55-69"
    4 = "4. 70-79"
    5 = "5. 80+"
    ;

value gender
    0 = "1. Males"
    1 = "2. Females"
;

value event
0 = "0. Censored"
1 = "1. Death"
;
run;

data dat; set foo.sampleData;

* BMI categories *;
if . < bmi < 18.5 then bmicat = 1;
else if bmi < 25 then bmicat = 2;
else if bmi < 30 then bmicat = 3;
else if bmi >= 30 then bmicat = 4;
format bmicat bmicat.;

* Hypertension *;
hypertension = 0;
if sysbp > 130 | diasbp > 85 then hypertension = 1;
format hypertension yesno.;

* age categories *;
if . < age < 40 then agecat = 1;
else if age < 55 then agecat = 2;
else if age < 70 then agecat = 3;
else if age < 80 then agecat = 4;
else agecat = 5;
format agecat agecat.

format gender gender.;
format fstat event.;
label hr="Heart Rate";
run;


* Frequency tables *;
%macro freq (var=);

proc freq data = dat;
tables &var * fstat/missing norow nocol nopercent nocum;
ods output CrossTabFreqs = freqtbl;
run;

data &var. (keep = &var fstat frequency);
    set freqtbl;
run;
%mend;


%freq(var=bmicat);
%freq(var=hypertension);
%freq(var=agecat);

ods excel file = "/users/briancarter/onedrive/sas/sas-r-test/output/frequencies.xlsx";

ods excel options (sheet_name = "BMICAT");
proc report data = bmicat;
    col bmicat frequency;
    define bmicat /group;
run;

ods excel options (sheet_name = "AGECAT");
proc report data = agecat;
    col agecat frequency;
    define agecat /group;
run;


ods excel options (sheet_name = "HYPERTENSION");
proc report data = hypertension;
    col hypertension frequency;
    define hypertension /group;
run;

ods excel close;



proc datasets lib=work;
 delete bmicat agecat hypertension;
run;




* Graphics *;
ods graphics on / imagename="/users/briancarter/onedrive/sas/sas-r-test/output/univariate";
proc univariate data = dat(where=(fstat=1));
    var lenfol;
    histogram lenfol;
run;





* Proportional hazards assumption *;
%macro phazards(var =, interaction =);


proc phreg data = dat;
    class bmicat;
    model lenfol * fstat(0) = &var &interaction;
    &interaction = &var * lenfol;
    ods output ParameterEstimates = &interaction;
run;

data &interaction; set &interaction (keep = parameter ProbChiSq);
    where parameter = "&interaction";
run;

%mend;




* Proportional hazards model *;
%macro model (var = , ref = );

proc phreg data = dat nosummary;
    class &var (ref = &ref);
    model lenfol*fstat(0)= &var/rl;
    strata age;
    ods output ParameterEstimates = &var.;
    run;

data &var. (keep = Parameter Label Estimate);
    set &var. (keep = Parameter Label Level1 HazardRatio HRLowerCL HRUpperCL);

array orig(*) HazardRatio HRLowerCL HRUpperCL;
array new(*) HR LL UL;
    do i = 1 to 3;
    new{i} = round(orig{i}, 0.01);
    end;

Estimate = cat(HR, " (", LL, ", ", UL, ")");

run;

%mend;


%model(var = bmicat, ref = "2. Normal weight");
%model(var = hypertension, ref = "0. No");
%model(var = gender, ref = "2. Females")


%phazards(var = bmicat, interaction = bmicat_t)
%phazards(var = hypertension, interaction = hypertension_t)
%phazards(var = gender, interaction = gender_t)



ods excel file = "/users/briancarter/onedrive/sas/sas-r-test/output/models.xlsx";
ods excel options (sheet_name = "BMICAT");
proc print data = bmicat noobs; run;

ods excel options (sheet_name = "HYPERTENSION");
proc print data = hypertension noobs; run;

ods excel options (sheet_name = "GENDER");
proc print data = gender noobs; run;

ods excel options (sheet_name = "PropHazards");
data prophaz; set bmicat_t hypertension_t gender_t;
run;
proc print data = prophaz noobs; run;
ods excel close;


proc datasets lib = work;
delete bmicat hypertension gender bmicat_t hypertension_t gender_t prophaz;
run;


* Kaplan-Meier curves *;
ods graphics on / imagename="/users/briancarter/onedrive/sas/sas-r-test/output/km";
proc lifetest data = dat;
    time lenfol * fstat(0);
    strata bmicat;
run;
ods graphics off;




