%{
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
void yyerror(const char *s)
{
    fprintf(stderr, "%s\n", s);
    exit(1);
}

int yylex(void);
%}


%union {
       char* lexeme;			//identifier
       double value;			//value of an identifier of type NUM
       }

%token <value>  NUM
%token IF
%token <lexeme> ID
%token UNARY_MINUS

%type <value> expr
%type <value> line

%start line

%left '+' '-'
%left '*' '/'

%%
line  : expr '\n'      {$$ = $1; printf("Result: %f\n", $$); exit(0);}
      ;
expr  : expr '+' expr  {$$ = $1 + $3;}
      | expr '-' expr  {$$ = $1 - $3;}
      | expr '*' expr  {$$ = $1 * $3;}
      | expr '/' expr  {$$ = $1 / $3;}
      | NUM            {$$ = $1;}
      | '-' expr       {$$ = -$2;}
      | ID             {$$=0; printf("IDENTIFICATORE = %s\n",$1);}
      ;

%%

#include "lex.yy.c"

int main(void)
{
  return yyparse();
}
