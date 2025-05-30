%{
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>


////////////// Symbol Table definitions //////////////
typedef enum {
    TYPE_INTEGER,
    TYPE_STRING,
    TYPE_DECIMAL
} variable_type_t;

// Struct that handles variables of different types
typedef struct {
    variable_type_t type;
    union {
        int ival;
        double dval;
        char* sval;
    } value;
} runtime_value_t;

// Struct that handles symbols of different types
typedef struct symbol {
    char* name;
    variable_type_t type;
    int scope_level;
    runtime_value_t value;
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
int hash(char* str);
symbol_t* lookup_in_scope(char* name, int scope);
void insert_symbol(char* name, variable_type_t type, int scope);
void assign_symbol(symbol_t *sym, runtime_value_t val);
int yylex(void);


%}


%union {
    int ivalue;
    double dvalue;
    char* svalue;
    symbol_t *symbol;
    runtime_value_t value;
}

%token <ivalue> L_INT
%token <dvalue> L_DECIMAL
%token <svalue> L_STRING
%token <svalue> ID
%token T_INT
%token T_STRING
%token T_DECIMAL

%type <value> expression
%type <symbol> declaration

%start program

%left '+' '-'
%left '*' '/'


%%

program : block
        ;
//function_def : type ID '(' params ')' { enter_scope(); } block { exit_scope(); }
//             ;
block : '{' { enter_scope(); } stmt_list '}' { exit_scope(); }
      ;
stmt_list : statement
          | stmt_list statement
          | block
          ;
statement : declaration '\n'
          | assignment '\n'
          ;
declaration : T_INT ID '\n'  {
                if (lookup_in_scope($2, current_scope) != NULL) {
                    yyerror("Variable already declared!");
                } else {
                    insert_symbol($2, TYPE_INTEGER, current_scope);
                }
            }
            | T_DECIMAL ID '\n' {
                if (lookup_in_scope($2, current_scope) != NULL) {
                    yyerror("Variable already declared!");
                } else {
                    insert_symbol($2, TYPE_DECIMAL, current_scope);
                }
            }
            | T_STRING ID '\n'  {
                if (lookup_in_scope($2, current_scope) != NULL) {
                    yyerror("Variable already declared!");
                } else {
                    insert_symbol($2, TYPE_STRING, current_scope);
                }
            }
            ;
assignment : ID '=' expression {
                symbol_t *symbol = lookup_in_scope($1, current_scope);
                if (symbol != NULL) {
                    assign_symbol(symbol, $3);
                } else {
                    yyerror("Undeclared variable");
                }
           }
           ;
expression : L_INT      { $$.type = T_INT; $$.value.ival = $1; }
           | L_DECIMAL  { $$.type = T_DECIMAL; $$.value.ival = $1; }
           | L_STRING   { $$.type = T_STRING; $$.value.ival = $1; }
           | ID         {
                symbol_t *symbol = lookup_in_scope($1, current_scope);
                if (symbol != NULL) {
                    $$ = symbol->value;
                } else {
                    yyerror("Undeclared variable");
                }
           }
           ;
/*
expression  : expression '+' expression  { $$ = $1 + $3; }
            | expression '-' expression  { $$ = $1 - $3; }
            | expression '*' expression  { $$ = $1 * $3; }
            | expression '/' expression  { $$ = $1 / $3; }
            | NUM                        { $$ = $1; }
            | '-' expression             { $$ = -$2; }
            | ID                         { $$=0; printf("IDENTIFIER = %s\n",$1); }
            ;
*/

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

int hash(char* str) {
    unsigned int hash = 0;
    while (*str) {
        hash = hash * 31 + *str++;
    }
    return hash % HASH_SIZE;
}

symbol_t* lookup_in_scope(char* name, int scope) {
    int h = hash(name);
    symbol_t* sym = symbol_table[h];

    while (sym) {
        if (strcmp(sym->name, name) == 0 && sym->scope_level == scope) {
            return sym;
        }
        sym = sym->next;
    }
    return NULL;
}

void insert_symbol(char* name, variable_type_t type, int scope) {
    int h = hash(name);
    symbol_t* new_sym = malloc(sizeof(symbol_t));
    new_sym->name = strdup(name);
    new_sym->type = type;
    new_sym->scope_level = scope;
    new_sym->next = symbol_table[h];
    symbol_table[h] = new_sym;
}

void assign_symbol(symbol_t *sym, runtime_value_t val) {
    if (sym->type != val.type) {
        yyerror("Type mismatch.");
        return;
    }
    sym->value = val;
}

int main(void)
{
  return yyparse();
}
