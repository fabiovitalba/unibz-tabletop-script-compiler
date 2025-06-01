%{
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"

////////////// Symbol Table definitions //////////////
typedef enum {
    TYPE_INTEGER,
    TYPE_STRING,
    TYPE_DECIMAL
} variable_type_t;

typedef enum {
    OP_ADDITION,
    OP_SUBTRACTION,
    OP_MULTIPLICATION,
    OP_DIVISION
} math_op_t;

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
void verify_types_match(runtime_value_t val1, runtime_value_t val2);
void assign_symbol(symbol_t *sym, runtime_value_t val);
void print_val(runtime_value_t val, int new_line);
runtime_value_t add_expressions(runtime_value_t val1, runtime_value_t val2);
runtime_value_t mathematical_operation(runtime_value_t val1, runtime_value_t val2, math_op_t op);
runtime_value_t negate_expression(runtime_value_t val);
runtime_value_t convert_to_type(runtime_value_t val, variable_type_t new_type);
runtime_value_t create_integer_value(int value);
runtime_value_t create_decimal_value(double value);
runtime_value_t create_string_value(char* value);
double get_numeric_value(runtime_value_t val);
char* get_string_value(runtime_value_t val);
int yylex(void);

%}


%union {
    int ivalue;
    double dvalue;
    char* svalue;
    symbol_t *symbol;
    runtime_value_t value;
}

%token <ivalue> L_INT_TOK
%token <dvalue> L_DEC_TOK
%token <svalue> L_STR_TOK
%token <svalue> ID_TOK
%token T_INT_TOK
%token T_STR_TOK
%token T_DEC_TOK
%token F_PRINT
%token F_PRINTLN
%token IF_TOK

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
          | statement stmt_list
          | block
          | block stmt_list
          ;
statement : declaration ';'
          | assignment ';'
          | function_exec ';'
          | IF_TOK '(' expression ')' block
          ;
declaration : T_INT_TOK ID_TOK      { $$ = declare_new_symbol($2,TYPE_INTEGER,current_scope); }
            | T_DEC_TOK ID_TOK      { $$ = declare_new_symbol($2,TYPE_DECIMAL,current_scope); }
            | T_STR_TOK ID_TOK      { $$ = declare_new_symbol($2,TYPE_STRING,current_scope); }
            ;
assignment : ID_TOK '=' expression {
                symbol_t *symbol = lookup_in_scope($1,current_scope);
                if (symbol != NULL) {
                    assign_symbol(symbol,$3);
                } else {
                    yyerror("Undeclared variable");
                }
           }
           ;
function_exec : ID_TOK '(' expression ')'           { ; }
              | F_PRINT '(' expression ')'      { print_val($3,0); }
              | F_PRINTLN '(' expression ')'    { print_val($3,1); }
              ;
expression : L_INT_TOK      { $$.type = TYPE_INTEGER; $$.value.ival = $1; }
           | L_DEC_TOK      { $$.type = TYPE_DECIMAL; $$.value.dval = $1; }
           | L_STR_TOK      { $$.type = TYPE_STRING; $$.value.sval = strdup($1); }
           | ID_TOK             {
                symbol_t *symbol = lookup_in_scope($1,current_scope);
                if (symbol != NULL) {
                    $$ = symbol->value;
                } else {
                    yyerror("Undeclared variable");
                }
           }
           | expression '+' expression  { $$ = add_expressions($1,$3); }
           | expression '-' expression  { $$ = mathematical_operation($1,$3,OP_SUBTRACTION); }
           | expression '*' expression  { $$ = mathematical_operation($1,$3,OP_MULTIPLICATION); }
           | expression '/' expression  { $$ = mathematical_operation($1,$3,OP_DIVISION); }
           | '-' expression             { $$ = negate_expression($2); }
           ;

%%


#include "lex.yy.c"


void enter_scope() {
    current_scope++;

    printf(ANSI_COLOR_GREEN);
    printf("Entering scope level %d\n", current_scope);
    printf(ANSI_COLOR_RESET);
}

void exit_scope() {
    printf(ANSI_COLOR_YELLOW);
    printf("Exiting scope level %d\n", current_scope);
    printf(ANSI_COLOR_RESET);

    // Remove all symbols at current scope level
    for (int i = 0; i < HASH_SIZE; i++) {
        symbol_t** sym_ptr = &symbol_table[i];
        while (*sym_ptr) {
            if ((*sym_ptr)->scope_level == current_scope) {
                symbol_t* to_remove = *sym_ptr;
                *sym_ptr = (*sym_ptr)->next;
                
                printf(ANSI_COLOR_RED);
                printf("Removing symbol: %s (scope %d)\n", to_remove->name, to_remove->scope_level);
                printf(ANSI_COLOR_RESET);

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
* This hash function takes the name of a symbol and returns an ID_TOK to be used
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
    int lookup_scope = scope;
    int h = hash(name);
    symbol_t* sym = symbol_table[h];

    while (lookup_scope >= 0) {
        printf(ANSI_COLOR_CYAN);
        printf("looking up %s (scope %d)\n", name, lookup_scope);
        printf(ANSI_COLOR_RESET);

        while (sym) {
            if (strcmp(sym->name, name) == 0 && sym->scope_level == lookup_scope) {
                return sym;
            }
            sym = sym->next;
        }
        lookup_scope--;
        sym = symbol_table[h];
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

void verify_types_match(runtime_value_t val1, runtime_value_t val2) {
    if (val1.type != val2.type) {
        if (((val1.type == TYPE_INTEGER) && (val2.type == TYPE_DECIMAL)) || ((val1.type == TYPE_DECIMAL) && (val2.type == TYPE_INTEGER)))
            return; // types can be matched

        if (val1.type == TYPE_STRING)
            return; // types can be matched as val2 will be converted to string.

        yyerror("Type mismatch.");
    }
}

void assign_symbol(symbol_t *sym, runtime_value_t val) {
    verify_types_match(sym->value,val);
    sym->value = convert_to_type(val,sym->value.type);
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
    verify_types_match(val1,val2);
    runtime_value_t result;
    switch(val1.type) {
        case TYPE_INTEGER:
        case TYPE_DECIMAL: {
            return mathematical_operation(val1,val2,OP_ADDITION);
        }
        case TYPE_STRING: {
            result.type = val1.type;
            char* str1 = get_string_value(val1);
            char* str2 = get_string_value(val2);
            int len1 = strlen(str1);
            int len2 = strlen(str2);
            
            char* concat_str = malloc(len1 + len2 + 1);
            if (!concat_str) {
                yyerror("Memory allocation failed");
                result.value.sval = NULL;
                return result;
            }
            
            strcpy(concat_str,str1);
            strcat(concat_str,str2);
            
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

runtime_value_t negate_expression(runtime_value_t val) {
    if (val.type == TYPE_STRING) {
        yyerror("Unsupported type for negation");
        return create_integer_value(0);
    }
    
    double numeric_val = get_numeric_value(val);
    if (val.type == TYPE_INTEGER) {
        return create_integer_value(-(int)numeric_val);
    }
    return create_decimal_value(-numeric_val);
}

runtime_value_t mathematical_operation(runtime_value_t val1, runtime_value_t val2, math_op_t op) {
    if (val1.type == TYPE_STRING || val2.type == TYPE_STRING) {
        yyerror("str does not support this operation.");
        return create_integer_value(0);
    }

    double num1 = get_numeric_value(val1);
    double num2 = get_numeric_value(val2);
    double result;

    switch(op) {
        case OP_ADDITION:
            result = num1 + num2;
            break;
        case OP_SUBTRACTION:
            result = num1 - num2;
            break;
        case OP_MULTIPLICATION:
            result = num1 * num2;
            break;
        case OP_DIVISION:
            if (num2 == 0) {
                yyerror("Division by zero");
                return create_integer_value(0);
            }
            result = num1 / num2;
            break;
        default:
            yyerror("Unknown operation");
            return create_integer_value(0);
    }

    if (val1.type == TYPE_INTEGER && val2.type == TYPE_INTEGER && 
        result == (int)result) {
        return create_integer_value((int)result);
    }
    
    return create_decimal_value(result);
}

runtime_value_t convert_to_type(runtime_value_t val, variable_type_t new_type) {
    if (val.type == new_type) {
        return val;
    }

    switch(new_type) {
        case TYPE_INTEGER:
            if (val.type == TYPE_DECIMAL) {
                return create_integer_value((int)val.value.dval);
            }
            if (val.type == TYPE_STRING) {
                return create_integer_value(atoi(val.value.sval));
            }
            break;

        case TYPE_DECIMAL:
            if (val.type == TYPE_INTEGER) {
                return create_decimal_value((double)val.value.ival);
            }
            if (val.type == TYPE_STRING) {
                return create_decimal_value(atof(val.value.sval));
            }
            break;

        case TYPE_STRING: {
            return create_string_value(get_string_value(val));
        }
    }

    yyerror("Type conversion impossible");
    return create_integer_value(0);
}

runtime_value_t create_integer_value(int value) {
    runtime_value_t result;
    result.type = TYPE_INTEGER;
    result.value.ival = value;
    return result;
}

runtime_value_t create_decimal_value(double value) {
    runtime_value_t result;
    result.type = TYPE_DECIMAL;
    result.value.dval = value;
    return result;
}

runtime_value_t create_string_value(char* value) {
    runtime_value_t result;
    result.type = TYPE_STRING;
    result.value.sval = strdup(value);
    return result;
}

double get_numeric_value(runtime_value_t val) {
    if (val.type == TYPE_INTEGER) {
        return (double)val.value.ival;
    }
    return val.value.dval;
}

char* get_string_value(runtime_value_t val) {
    char buffer[100]; // 100 is enough for both double and integer
    switch(val.type) {
        case TYPE_INTEGER: {
            sprintf(buffer, "%d", val.value.ival);
            return strdup(buffer);
        }
        case TYPE_DECIMAL: {
            sprintf(buffer, "%f", val.value.dval);
            return strdup(buffer);
        }
        case TYPE_STRING: {
            if (val.value.sval != NULL) {
                return val.value.sval;
            } else {
                return "(undefined)";
            }
        }
    }
    yyerror("Conversion to string impossible.");
    return NULL;
}

int main(void)
{
    return yyparse();
}
