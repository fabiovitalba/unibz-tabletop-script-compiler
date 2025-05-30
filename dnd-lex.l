%option noyywrap
%{
#include "dnd-compiler.tab.h"
#include <stdlib.h>
%}


/* Building Blocks */
DIGIT       [0-9]
NUM         {DIGIT}+(\.{DIGIT}+)?
LETTER      [a-zA-Z_]
ALPHANUM    [a-zA-Z0-9_]
ID          {LETTER}{ALPHANUM}*


%%


/* Keywords */
"int"       { return SET_INT; }
"string"    { return SET_STRING; }
"decimal"   { return SET_DECIMAL; }

/* Dice notation */
{DIGIT}+[dD]{DIGIT}+ {
    printf("TOKEN: DICE_EXPRESSION (%s)\n", yytext);

    char* d_pos = strchr(yytext, 'd');
    if (!d_pos) d_pos = strchr(yytext, 'D');

    *d_pos = '\0';  /* Split the string */
    int num_dice = atoi(yytext);
    int die_sides = atoi(d_pos + 1);

    yylval.ival = num_dice * 1000 + die_sides;  /* Encode both values */
    return DICE_TOKEN;
}

[ ]     { /* skip blanks */ }

[iI][fF] {
    return IF;
}

{NUM}   {
    yylval.value = atof(yytext);
    return NUM;
}

{ID}    {
    yylval.lexeme = yytext;
    return ID;
}

"+"     { return '+'; }
"-"     { return '-'; }
"*"     { return '*'; }
"/"     { return '/'; }
\n      { return '\n'; }


%%

