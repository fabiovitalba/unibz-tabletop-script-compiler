%option noyywrap
%{
#include "dnd-compiler.tab.h"
#include <stdlib.h>

int line_number = 1;
%}


/* Building Blocks */
DIGIT       [0-9]
INTEGER     {DIGIT}+
REAL        {INTEGER}(\.{DIGIT}+)?
LETTER      [a-zA-Z_]
ALPHANUM    [a-zA-Z0-9_]
ID          {LETTER}{ALPHANUM}*


%%


    /* Keywords */
"int"       { return T_INT; }
"dec"       { return T_DECIMAL; }
"str"       { return T_STRING; }

[ ]         { /* skip blanks */ }
\n          { /* skip newlines */ line_number++; }
\t          { /* skip tabs */ }

    /*[iI][fF] {
    return IF;
    }*/

{INTEGER}   {
    yylval.ivalue = atoi(yytext);
    return L_INT;
}

{REAL}      {
    yylval.dvalue = atof(yytext);
    return L_DECIMAL;
}

\"[^\"]*\"  {
    yylval.svalue = strdup(yytext); // duplicate string, since yytext is overwritten constantly
    return L_STRING;
}

{ID}        {
    yylval.svalue = strdup(yytext); // duplicate string, since yytext is overwritten constantly
    return ID;
}

    /* Operators, Scopes and Delimiters */
"+"     { return '+'; }
"-"     { return '-'; }
"*"     { return '*'; }
"/"     { return '/'; }
"{"     { return '{'; }
"}"     { return '}'; }
"("     { return '('; }
")"     { return ')'; }
"="     { return '='; }
"\""    { return '"'; }
";"     { return ';'; }

    /* Catch-all for unrecognized characters */
.               {
    printf("ERROR: Unrecognized character '%c' at line %d\n",
           yytext[0], line_number);
    return yytext[0];
}

%%

/* Additional C code */
void init_lexer() {
    line_number = 1;
}
