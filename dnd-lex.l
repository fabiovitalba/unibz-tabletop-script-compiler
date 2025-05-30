%option noyywrap
%{
#include "dnd-compiler.tab.h"
#include <stdlib.h>
%}


/* Building Blocks */
DIGIT       [0-9]
INTEGER     {DIGIT}+
REAL        {INTEGER}(\.{DIGIT}+)?
LETTER      [a-zA-Z_]
ALPHANUM    [a-zA-Z0-9_]
STRING      [{ALPHANUM} _,.!?]*
ID          {LETTER}{ALPHANUM}*


%%


    /* Keywords */
"int"       { return T_INT; }
"str"    { return T_STRING; }
"dec"   { return T_DECIMAL; }

[ ]     { /* skip blanks */ }

    /*[iI][fF] {
    return IF;
    }*/

{INTEGER}   {
    yylval.ivalue = atof(yytext);
    return L_INT;
}

{REAL}   {
    yylval.dvalue = atof(yytext);
    return L_DECIMAL;
}

[\"{STRING}\"][\'{STRING}\']    {
    yylval.svalue = yytext;
    return L_STRING;
}

{ID}    {
    yylval.svalue = yytext;
    return ID;
}

"+"     { return '+'; }
"-"     { return '-'; }
"*"     { return '*'; }
"/"     { return '/'; }
\n      { return '\n'; }
"{"     { return '{'; }
"}"     { return '}'; }
"("     { return '('; }
")"     { return ')'; }
"="     { return '='; }
"\""      { return '"'; }


%%

