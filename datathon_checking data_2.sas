
LIBNAME mylib "P:\[Datathon]";

PROC IMPORT DATAFILE="P:\[Datathon]\finaltable1.csv" 
    OUT=mylib.final_dataset1
    DBMS=CSV
    REPLACE;
    GETNAMES=YES;
    GUESSINGROWS=32767;
RUN;

PROC CONTENTS DATA=mylib.final_dataset1;
RUN;

PROC LOGISTIC DATA=mylib.final_dataset1 DESCENDING;
    CLASS 
        gender(ref='Male') 
        ethnicity(ref='Caucasian')
        sepsis(ref='0')
        chronically_hypoxic(ref='0')
    / PARAM=REF;

    MODEL hospitaldischargestatus (event='Expired') =
        auc_change        
        age
        apachescore
        BMI
        base_fio2
        MBP
        final_charlson_score
        gender
        ethnicity
        sepsis
        chronically_hypoxic
    / CLODDS=WALD;

   
RUN;

PROC GENMOD DATA=mylib.final_dataset1;
    CLASS
        gender(ref='Male')
        ethnicity(ref='Caucasian')
        sepsis(ref='0')
        chronically_hypoxic(ref='0')
    / PARAM=REF;

    MODEL hospitaldischargeoffset =
        auc_change        
        age
        apachescore
        BMI
        base_fio2
        MBP
        final_charlson_score
        gender
        ethnicity
        sepsis
        chronically_hypoxic
    / DIST=NEGBIN LINK=LOG TYPE3 LRCI;

   
RUN;


ods graphics on;


PROC LOGISTIC DATA=mylib.final_dataset1 DESCENDING 
              PLOTS(ONLY)=(ROC(ID=prob));
    CLASS gender(ref='Male') ethnicity(ref='Caucasian') / PARAM=REF;

    MODEL hospitaldischargestatus(event='Expired') = 
       
        auc_change 
        age
        apachescore
        BMI
        base_fio2
        MBP
        final_charlson_score
        gender
        ethnicity
        sepsis
        chronically_hypoxic
        / SELECTION=NONE LINK=LOGIT;

    
RUN;

ods graphics off;





















/*checking VIF*/

PROC REG DATA=mylib.final_dataset1;
    MODEL auc_change = final_charlson_score sepsis age apachescore BMI base_fio2 MBP
         / VIF TOL COLLIN;
    /*
       - dummy_y? ??? ???? (???? ?? ???? ??)
       - VIF, TOL : ????? ??(??????, ???)
       - COLLIN   : Condition Index, Eigenvalues ? ?????? ??
    */
RUN;
QUIT;

proc corr data=mylib.final_dataset1; 
var auc_change age apachescore base_fio2 mbp 
  
        BMI
    
        final_charlson_score
    
        sepsis
        chronically_hypoxic; run; 








*******************
*******Making Graphs*****


		ods graphics on;

PROC LOGISTIC DATA=mylib.final_dataset1 DESCENDING
              PLOTS(ONLY)=(ROC(ID=prob) EFFECT ODDSRATIO);
    CLASS gender(ref='Male') ethnicity(ref='Caucasian') / PARAM=REF;
    MODEL hospitaldischargestatus(event='Expired') = 
        auc_change age apachescore BMI base_fio2 MBP final_charlson_score
        gender ethnicity sepsis chronically_hypoxic
        / SELECTION=NONE CTABLE;

    /* 
       PLOTS(ONLY) ??? ROC, EFFECT, ODDSRATIO ?? ??
       - ROC(ID=prob): ROC ??? ???, ??? ?? ??(??)
       - EFFECT: ?? ??(?? ??? ?? ?? ?? ??)
       - ODDSRATIO: OR ??
       CTABLE: ?????
    */
RUN;


ods graphics off;

ods graphics on;

PROC GENMOD DATA=mylib.final_dataset1;
    CLASS gender(ref='Male') ethnicity(ref='Caucasian') / PARAM=REF;
    MODEL hospitaldischargeoffset = 
        auc_change age apachescore BMI base_fio2 MBP final_charlson_score
        gender ethnicity sepsis chronically_hypoxic
        / DIST=NEGBIN LINK=LOG TYPE3;

    OUTPUT OUT=genmod_out 
        PRED=pred_nb  /* ??? */
        RESCHI=reschi /* ???(chi) ?? */
        STDRESCH=stdreschi /* ??? ??? ?? */
        XBETA=xbeta   /* ????? (log scale) */
    ;
RUN;

ods graphics off;

PROC SGPLOT DATA=genmod_out;
    SCATTER x=pred_nb y=hospitaldischargeoffset / markerattrs=(symbol=circlefilled);
    LINEPARM x=0 y=0; /* ???? ??? */
    XAXIS LABEL="Predicted LOS (NB model)";
    YAXIS LABEL="Observed LOS";
RUN;

PROC SGPLOT DATA=genmod_out;
    SCATTER x=pred_nb y=stdreschi / markerattrs=(color=blue symbol=circlefilled);
    REFLINE 0 / axis=y lineattrs=(color=red);
    XAXIS LABEL="Predicted LOS (NB)";
    YAXIS LABEL="Standardized Residual";
RUN;


PROC SGSCATTER DATA=mylib.final_dataset1;
    MATRIX age apachescore base_fio2 MBP BMI final_charlson_score auc_change
        / DIAGONAL=(histogram kernel);
    /*
       - MATRIX ?: ?? ??
       - DIAGONAL=(histogram kernel): ???? ?????+????
       => ? ?? ? ???, ??? ??
    */
RUN;




ods graphics on;

PROC LOGISTIC DATA=mylib.final_dataset1 DESCENDING plots=none;
    CLASS gender(ref='Male') ethnicity(ref='Caucasian') / PARAM=REF;

    MODEL hospitaldischargestatus(event='Expired') =
        auc_change age apachescore BMI base_fio2
        MBP final_charlson_score
        gender ethnicity sepsis chronically_hypoxic
        / SELECTION=NONE LINK=LOGIT;

    /* ?: age(???), delta_auc(???)? ?? ?? ?? */
    EFFECTPLOT slicefit(x=delta_auc)
        / CLM  /* ???? */
          CLBAND /* ???? ?? */
          at(age=50 base_fio2=30 apachescore=60) 
          /* ??? ??? ?? ??? ??? ? delta_auc? ????? ?? */
          ;
    /* ???? age? ?? ??? ??? ???: */
    EFFECTPLOT slicefit(x=age)
        / at(auc_change=500 base_fio2=30 apachescore=60);

RUN;

ods graphics off;
ods graphics on;

PROC GENMOD DATA=mylib.final_dataset1;
    CLASS gender(ref='Male') ethnicity(ref='Caucasian') / PARAM=REF;
    MODEL hospitaldischargeoffset =
        auc_change age apachescore BMI base_fio2 MBP final_charlson_score
        gender ethnicity sepsis chronically_hypoxic
        / DIST=NEGBIN LINK=LOG TYPE3;

    EFFECTPLOT FIT(X=delta_auc) / AT(age=50 apachescore=60 base_fio2=30);
    /*
      => delta_auc? ??? ?, ??? LOS(??? link=log) ?? ??
      => ?? ?? age, apachescore, etc. ??
    */

RUN;

ods graphics off;

ods graphics on;

PROC REG DATA=mylib.final_Dataset1 PLOTS(ONLY)=(PARTIAL);
    MODEL auc_change = final_charlson_score sepsis age apachescore 
                       BMI base_fio2 MBP;
    /* PARTIAL => ???? ??(? ?????? ?? vs ??) */
RUN;

ods graphics off;
