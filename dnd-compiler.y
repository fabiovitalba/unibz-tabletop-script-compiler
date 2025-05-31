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
    int scope_level;
    runtime_value_t value;
    struct symbol* next;
} symbol_t;

/*
The symbol_table is an array of HASH_SIZE linked lists containing symbol_t elements.
We use size 101 because it's a prime and allows for even distribution in the hash table.
*/
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
symbol_t* declare_new_symbol(char* name, variable_type_t type, int scope);
symbol_t* lookup_in_scope(char* name, int scope);
void insert_symbol(char* name, variable_type_t type, int scope);
void test_match_types(runtime_value_t val1, runtime_value_t val2);
void assign_symbol(symbol_t *sym, runtime_value_t val);
void print_val(runtime_value_t val, int new_line);
runtime_value_t add_expressions(runtime_value_t val1, runtime_value_t val2);
runtime_value_t subtract_expressions(runtime_value_t val1, runtime_value_t val2);
runtime_value_t multiply_expressions(runtime_value_t val1, runtime_value_t val2);
runtime_value_t divide_expressions(runtime_value_t val1, runtime_value_t val2);
runtime_value_t negate_expression(runtime_value_t val);
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
%token F_PRINT
%token F_PRINTLN

%type <value> expression
%type <symbol> declaration

%start program

%left '+' '-'
%left '*' '/'


%%

program : block
        ;
block : '{' { enter_scope(); } stmt_list '}' { exit_scope(); }
      ;
stmt_list : statement
          | stmt_list statement
          | block
          ;
statement : declaration ';'
          | assignment ';'
          | function_exec ';'
          ;
declaration : T_INT ID      { $$ = declare_new_symbol($2,TYPE_INTEGER,current_scope); }
            | T_DECIMAL ID  { $$ = declare_new_symbol($2,TYPE_DECIMAL,current_scope); }
            | T_STRING ID   { $$ = declare_new_symbol($2,TYPE_STRING,current_scope); }
            ;
assignment : ID '=' expression {
                symbol_t *symbol = lookup_in_scope($1,current_scope);
                if (symbol != NULL) {
                    assign_symbol(symbol,$3);
                } else {
                    yyerror("Undeclared variable");
                }
           }
           ;
function_exec : ID '(' expression ')'           { ; }
              | F_PRINT '(' expression ')'      { print_val($3,0); }
              | F_PRINTLN '(' expression ')'    { print_val($3,1); }
              ;
expression : L_INT      { $$.type = TYPE_INTEGER; $$.value.ival = $1; }
           | L_DECIMAL  { $$.type = TYPE_DECIMAL; $$.value.dval = $1; }
           | L_STRING   { $$.type = TYPE_STRING; $$.value.sval = strdup($1); }
           | ID         {
                symbol_t *symbol = lookup_in_scope($1,current_scope);
                if (symbol != NULL) {
                    $$ = symbol->value;
                } else {
                    yyerror("Undeclared variable");
                }
           }
           | expression '+' expression  { $$ = add_expressions($1,$3); }
           | expression '-' expression  { $$ = subtract_expressions($1,$3); }
           | expression '*' expression  { $$ = multiply_expressions($1,$3); }
           | expression '/' expression  { $$ = divide_expressions($1,$3); }
           | '-' expression             { $$ = negate_expression($2); }
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

/**
* This hash function takes the name of a symbol and returns an ID to be used
* within the symbol table array. This distributes the symbols evenly within
* the hash table.
* We multiply by 31 (prime number) in order to have a better distribution of
* values within the hash table.
*/
int hash(char* str) {
    unsigned int hash = 0;
    while (*str) {
        hash = hash * 31 + *str++;
    }
    return hash % HASH_SIZE;
}

symbol_t* declare_new_symbol(char* name, variable_type_t type, int scope) {
    if (lookup_in_scope(name,scope) != NULL) {
        yyerror("Variable already declared!");
        return NULL;
    } else {
        insert_symbol(name,type,scope);
        return lookup_in_scope(name,scope);
    }
}

symbol_t* lookup_in_scope(char* name, int scope) {
    //printf("looking up %s (scope %d)\n", name, scope);
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
    new_sym->value.type = type;
    new_sym->scope_level = scope;
    new_sym->next = symbol_table[h];
    symbol_table[h] = new_sym;
}

void test_match_types(runtime_value_t val1, runtime_value_t val2) {
    if (val1.type != val2.type) {
        yyerror("Type mismatch.");
    }
}

void assign_symbol(symbol_t *sym, runtime_value_t val) {
    test_match_types(sym->value, val);
    sym->value = val;
}

void print_val(runtime_value_t val, int new_line) {
    switch(val.type) {
        case TYPE_INTEGER: {
            printf("%d",val.value.ival);
            break;
        }
        case TYPE_DECIMAL: {
            printf("%f",val.value.dval);
            break;
        }
        case TYPE_STRING: {
            printf("%s",val.value.sval);
            break;
        }
        default:
            yyerror("Unsupported type for print.");
    }
    if (new_line) {
        printf("\n");
    }
}

runtime_value_t add_expressions(runtime_value_t val1, runtime_value_t val2) {
    test_match_types(val1, val2);
    runtime_value_t result;
    result.type = val1.type;
    switch(val1.type) {
        case TYPE_INTEGER: {
            result.value.ival = val1.value.ival + val2.value.ival;
            break;
        }
        case TYPE_DECIMAL: {
            result.value.dval = val1.value.dval + val2.value.dval;
            break;
        }
        case TYPE_STRING: {
            int len1 = strlen(val1.value.sval);
            int len2 = strlen(val2.value.sval);
            
            char* concat_str = malloc(len1 + len2 + 1);
            if (!concat_str) {
                yyerror("Memory allocation failed");
                result.value.sval = NULL;
                return result;
            }
            
            strcpy(concat_str, val1.value.sval);
            strcat(concat_str, val2.value.sval);
            
            result.value.sval = concat_str;
            break;
        }
        default:
            yyerror("Unsupported type for addition");
            result.type = TYPE_INTEGER;
            result.value.ival = 0;
    }

    return result;
}

runtime_value_t subtract_expressions(runtime_value_t val1, runtime_value_t val2) {
    test_match_types(val1, val2);
    runtime_value_t result;
    result.type = val1.type;
    switch(val1.type) {
        case TYPE_INTEGER: {
            result.value.ival = val1.value.ival - val2.value.ival;
            break;
        }
        case TYPE_DECIMAL: {
            result.value.dval = val1.value.dval - val2.value.dval;
            break;
        }
        default:
            yyerror("Unsupported type for subtraction");
            result.type = TYPE_INTEGER;
            result.value.ival = 0;
    }

    return result;
}

runtime_value_t multiply_expressions(runtime_value_t val1, runtime_value_t val2) {
    test_match_types(val1, val2);
    runtime_value_t result;
    result.type = val1.type;
    switch(val1.type) {
        case TYPE_INTEGER: {
            result.value.ival = val1.value.ival * val2.value.ival;
            break;
        }
        case TYPE_DECIMAL: {
            result.value.dval = val1.value.dval * val2.value.dval;
            break;
        }
        default:
            yyerror("Unsupported type for multiplication");
            result.type = TYPE_INTEGER;
            result.value.ival = 0;
    }

    return result;
}

runtime_value_t divide_expressions(runtime_value_t val1, runtime_value_t val2) {
    test_match_types(val1, val2);
    runtime_value_t result;
    result.type = val1.type;
    switch(val1.type) {
        case TYPE_INTEGER: {
            result.value.ival = val1.value.ival / val2.value.ival;
            break;
        }
        case TYPE_DECIMAL: {
            result.value.dval = val1.value.dval / val2.value.dval;
            break;
        }
        default:
            yyerror("Unsupported type for division");
            result.type = TYPE_INTEGER;
            result.value.ival = 0;
    }

    return result;
}

runtime_value_t negate_expression(runtime_value_t val) {
    runtime_value_t result;
    result.type = val.type;
    switch(val.type) {
        case TYPE_INTEGER: {
            result.value.ival = -val.value.ival;
            break;
        }
        case TYPE_DECIMAL: {
            result.value.dval = -val.value.dval;
            break;
        }
        default:
            yyerror("Unsupported type for negation");
            result.type = TYPE_INTEGER;
            result.value.ival = 0;
    }

    return result;
}

int main(void)
{
  return yyparse();
}
