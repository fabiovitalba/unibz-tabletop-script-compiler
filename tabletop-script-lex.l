%option noyywrap
%option yylineno

%{
#include "tabletop-script-compiler.tab.h"
#include <stdlib.h>
%}

/* Building Blocks */
DIGIT       [0-9]
INTEGER     {DIGIT}+
REAL        {INTEGER}(\.{DIGIT}+)?
LETTER      [a-zA-Z_]
ALPHANUM    [a-zA-Z0-9_]
ID_TOK      {LETTER}{ALPHANUM}*


%%


    /* Keywords */
"int"       { return T_INT_TOK; }
"dec"       { return T_DEC_TOK; }
"str"       { return T_STR_TOK; }
"if"        { return IF_TOK; }
"prt"       { return F_PRINT; }
"prtln"     { return F_PRINTLN; }
"adv"       { return ADV_TOK; }
"dadv"      { return DADV_TOK; }
">"         { return GT_TOK; }
">="        { return GTOE_TOK; }
"<"         { return LT_TOK; }
"<="        { return LTOE_TOK; }
"=="        { return EQ_TOK; }
"!="        { return NEQ_TOK; }

[ ]         { /* skip blanks */ }
\n          { /* skip newlines */ }
\t          { /* skip tabs */ }
"//".*\n    { /* skip comment lines */ }

[0-9]+[dD][0-9]+    {
    // Duplicate the received string in order to keep it
    yylval.svalue = strdup(yytext);
    return DICE_TOK;
}

{INTEGER}   {
    // Convert the received text value to int
    yylval.ivalue = atoi(yytext);
    return L_INT_TOK;
}

{REAL}      {
    // Convert the received text value to double
    yylval.dvalue = atof(yytext);
    return L_DEC_TOK;
}

\"[^\"]*\"  {
    // We have to remove the leading and ending quotes (") from the string.
    // Then we also have to copy the string from yytext as it will be overwritten
    int len = strlen(yytext) - 2;
    yylval.svalue = malloc(len + 1);
    strncpy(yylval.svalue, yytext + 1, len);
    yylval.svalue[len] = '\0';
    return L_STR_TOK;
}

{ID_TOK}        {
    // We have to duplicate the string, since yytext is overwritten constantly
    yylval.svalue = strdup(yytext);
    return ID_TOK;
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
    printf("Lexer Error: Unrecognized character '%c' at line %d\n",
           yytext[0], yylineno);
    return yytext[0];
}

%%

