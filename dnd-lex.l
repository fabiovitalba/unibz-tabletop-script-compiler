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
"int"       { return T_INT_TOK; }
"dec"       { return T_DEC_TOK; }
"str"       { return T_STR_TOK; }
"prt"       { return F_PRINT; }
"prtln"     { return F_PRINTLN; }

[ ]         { /* skip blanks */ }
\n          { /* skip newlines */ line_number++; }
\t          { /* skip tabs */ }
"//".*\n    { /* skip comment lines */ }

    /*[iI][fF] {
    return IF;
    }*/

{INTEGER}   {
    yylval.ivalue = atoi(yytext);
    return L_INT_TOK;
}

{REAL}      {
    yylval.dvalue = atof(yytext);
    return L_DEC_TOK;
}

\"[^\"]*\"  {
    int len = strlen(yytext) - 2;
    yylval.svalue = malloc(len + 1);
    strncpy(yylval.svalue, yytext + 1, len);
    yylval.svalue[len] = '\0';
    return L_STR_TOK;
}

{ID}        {
    yylval.svalue = strdup(yytext); // duplicate string, since yytext is overwritten constantly
    return ID;
}

    /* Operators, Scopes and Delimiters */
"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }
"{"         { return '{'; }
"}"         { return '}'; }
"("         { return '('; }
")"         { return ')'; }
"="         { return '='; }
"\""        { return '"'; }
";"         { return ';'; }

    /* Catch-all for unrecognized characters */
.           {
    printf("ERROR: Unrecognized character '%c' at line %d\n",
           yytext[0], line_number);
    return yytext[0];
}

%%

/* Additional C code */
void init_lexer() {
    line_number = 1;
}
