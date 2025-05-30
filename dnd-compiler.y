%{
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>


////////////// Symbol Table definitions //////////////
typedef struct symbol {
    char* name;
    symbol_type_t type;
    int scope_level;
    int value;  // for stats/inventory quantities
    struct symbol* next;
} symbol_t;

#define HASH_SIZE 101
symbol_t* symbol_table[HASH_SIZE];
int current_scope = 0;


////////////// Methods and Functions //////////////
void yyerror(const char *s)
{
    fprintf(stderr, "%s\n", s);
    exit(1);
}

void enter_scope();
void exit_scope();
int yylex(void);


%}


%union {
       char* svalue;			// value of type string
       double dvalue;			// value of type double
       int ivalue;              // value of type int
}

%token <dvalue>  NUM
%token IF
%token <svalue> ID
%token UNARY_MINUS
%token DICE_TOKEN
%token <ivalue> SET_INT
%token <svalue> SET_STRING
%token <dvalue> SET_DECIMAL

%type <dvalue> expr
%type <dvalue> line

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
      | ID             {$$=0; printf("IDENTIFIER = %s\n",$1);}
      ;


%%


#include "lex.yy.c"


void enter_scope() {
    current_scope++;
    printf("Entering scope level %d\n", current_scope);
}

void exit_scope() {
    printf("Exiting scope level %d\n", current_scope);

    // Remove all symbols at current scope level
    for (int i = 0; i < HASH_SIZE; i++) {
        symbol_t** sym_ptr = &symbol_table[i];
        while (*sym_ptr) {
            if ((*sym_ptr)->scope_level == current_scope) {
                symbol_t* to_remove = *sym_ptr;
                *sym_ptr = (*sym_ptr)->next;
                printf("Removing symbol: %s (scope %d)\n",
                       to_remove->name, to_remove->scope_level);
                free(to_remove->name);
                free(to_remove);
            } else {
                sym_ptr = &((*sym_ptr)->next);
            }
        }
    }

    current_scope--;
}

int main(void)
{
  return yyparse();
}
