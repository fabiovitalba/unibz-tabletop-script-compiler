%{
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

// Colors used in DEBUG_MODE logging
#define TEXT_COLOR_RED     "\e[0;31m"
#define TEXT_COLOR_GREEN   "\e[0;32m"
#define TEXT_COLOR_YELLOW  "\e[0;33m"
#define TEXT_COLOR_BLUE    "\e[0;34m"
#define TEXT_COLOR_MAGENTA "\e[0;35m"
#define TEXT_COLOR_CYAN    "\e[0;36m"
#define TEXT_COLOR_RESET   "\e[0m"

int DEBUG_MODE = 0; // Set to 1 to enable, 0 to disable additional logging

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
    OP_DIVISION,
    OP_GREATER,
    OP_GREATER_EQUAL,
    OP_LESS,
    OP_LESS_EQUAL,
    OP_EQUAL,
    OP_NOT_EQUAL
} math_op_t;

typedef enum {
    ROLL_NORMAL,
    ROLL_W_ADV,
    ROLL_W_DADV
} dice_mod_t;

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

/*
The if_tracker_stack keeps track of which if conditions evaluated to true and which did not.
*/
#define IF_TRACKER_SIZE 255
int if_condition_result[IF_TRACKER_SIZE];
int if_condition_id = 0;

/*
current_scope keeps track of the currently active scope ID
*/
int current_scope = 0;

extern int yylineno; // used to track error line no.

////////////// Methods and Functions //////////////
void enter_scope();
void exit_scope();
int hash(char* str);
symbol_t* declare_new_symbol(char* name, variable_type_t type, int scope);
symbol_t* lookup_in_scope(char* name, int scope);
symbol_t* lookup(char* name, int scope);
symbol_t* insert_symbol(char* name, variable_type_t type, int scope);
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
runtime_value_t compare_expressions(runtime_value_t val1, runtime_value_t val2, math_op_t op);
int expression_is_true(runtime_value_t val);
void add_if_condition(int result);
void pop_if_condition();
int should_execute_stmt();
runtime_value_t roll_dice_from_string(char* dice_text, dice_mod_t roll_mod);
runtime_value_t roll_dice(int no_of_dice, int no_of_faces, dice_mod_t roll_mod);
int yylex(void);

void yyerror(const char *s)
{
    fprintf(stderr, "%s on line %d\n", s, yylineno);
    // In case of an error, we have to free any allocated memory
    while (current_scope > 0) {
        exit_scope();
    }
    exit(1);
}

%}

%locations

%union {
    int ivalue;
    double dvalue;
    char* svalue;
    symbol_t* symbol;
    runtime_value_t value;
}

%token <ivalue> L_INT_TOK
%token <dvalue> L_DEC_TOK
%token <svalue> L_STR_TOK
%token <svalue> DICE_TOK
%token <svalue> ID_TOK
%token T_INT_TOK
%token T_STR_TOK
%token T_DEC_TOK
%token F_PRINT
%token F_PRINTLN
%token IF_TOK
%token GT_TOK
%token GTOE_TOK
%token LT_TOK
%token LTOE_TOK
%token EQ_TOK
%token NEQ_TOK
%token ADV_TOK
%token DADV_TOK

%type <value> expression
%type <symbol> declaration

%start program

%left '+' '-'
%left '*' '/'
%left GT_TOK GTOE_TOK LT_TOK LTOE_TOK
%left EQ_TOK NEQ_TOK
%nonassoc UMINUS


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
          | IF_TOK '(' expression ')' { if (should_execute_stmt()) add_if_condition(expression_is_true($3)); } block { pop_if_condition(); }
          ;
declaration : T_INT_TOK ID_TOK      { if (should_execute_stmt()) $$ = declare_new_symbol($2,TYPE_INTEGER,current_scope); }
            | T_DEC_TOK ID_TOK      { if (should_execute_stmt()) $$ = declare_new_symbol($2,TYPE_DECIMAL,current_scope); }
            | T_STR_TOK ID_TOK      { if (should_execute_stmt()) $$ = declare_new_symbol($2,TYPE_STRING,current_scope); }
            ;
assignment : ID_TOK '=' expression {
                if (should_execute_stmt()) {
                    symbol_t *symbol = lookup($1,current_scope);
                    if (symbol != NULL) {
                        assign_symbol(symbol,$3);
                    } else {
                        yyerror("Undeclared variable");
                    }
                }
           }
           ;
function_exec : F_PRINT '(' expression ')'      { if (should_execute_stmt()) print_val($3,0); }
              | F_PRINTLN '(' expression ')'    { if (should_execute_stmt()) print_val($3,1); }
              ;
expression : L_INT_TOK          { $$.type = TYPE_INTEGER; $$.value.ival = $1; }
           | L_DEC_TOK          { $$.type = TYPE_DECIMAL; $$.value.dval = $1; }
           | L_STR_TOK          { $$.type = TYPE_STRING; $$.value.sval = strdup($1); }
           | DICE_TOK           { $$ = roll_dice_from_string($1,ROLL_NORMAL); }
           | DICE_TOK ADV_TOK   { $$ = roll_dice_from_string($1,ROLL_W_ADV); }
           | DICE_TOK DADV_TOK  { $$ = roll_dice_from_string($1,ROLL_W_DADV); }
           | ID_TOK             {
                symbol_t *symbol = lookup($1,current_scope);
                if (symbol != NULL) {
                    $$ = symbol->value;
                } else {
                    yyerror("Undeclared variable");
                }
           }
           | '(' expression ')'             { $$ = $2; }
           | '-' expression %prec UMINUS    { $$ = negate_expression($2); }
           | expression EQ_TOK expression   { $$ = compare_expressions($1,$3,OP_EQUAL); }
           | expression NEQ_TOK expression  { $$ = compare_expressions($1,$3,OP_NOT_EQUAL); }
           | expression GT_TOK expression   { $$ = compare_expressions($1,$3,OP_GREATER); }
           | expression GTOE_TOK expression { $$ = compare_expressions($1,$3,OP_GREATER_EQUAL); }
           | expression LT_TOK expression   { $$ = compare_expressions($1,$3,OP_LESS); }
           | expression LTOE_TOK expression { $$ = compare_expressions($1,$3,OP_LESS_EQUAL); }
           | expression '+' expression      { $$ = add_expressions($1,$3); }
           | expression '-' expression      { $$ = mathematical_operation($1,$3,OP_SUBTRACTION); }
           | expression '*' expression      { $$ = mathematical_operation($1,$3,OP_MULTIPLICATION); }
           | expression '/' expression      { $$ = mathematical_operation($1,$3,OP_DIVISION); }
           ;

%%


#include "lex.yy.c"


/**
* Increments the scope ID
*/
void enter_scope() {
    current_scope++;

    if (DEBUG_MODE) {
        printf(TEXT_COLOR_GREEN);
        printf("Entering scope level %d\n", current_scope);
        printf(TEXT_COLOR_RESET);
    }
}

/**
* Frees any allocated memory from the current scope. Then reduces the scope ID by 1.
* Updates the next-pointer where necessary before symbols are freed.
*/
void exit_scope() {
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_YELLOW);
        printf("Exiting scope level %d\n", current_scope);
        printf(TEXT_COLOR_RESET);
    }

    // Remove all symbols at current scope level
    for (int i = 0; i < HASH_SIZE; i++) {
        symbol_t** sym_ptr = &symbol_table[i];
        while (*sym_ptr) {
            if ((*sym_ptr)->scope_level == current_scope) {
                symbol_t* to_remove = *sym_ptr;
                *sym_ptr = (*sym_ptr)->next;
                
                if (DEBUG_MODE) {
                    printf(TEXT_COLOR_RED);
                    printf("Removing symbol: %s (scope %d)\n", to_remove->name, to_remove->scope_level);
                    printf(TEXT_COLOR_RESET);
                }

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

/**
* Used to declare new symbols that have to be stored in the symbol table.
* Throws an error if the symbol is already present in the symbol table.
* Otherwise returns the symbol struct.
*/
symbol_t* declare_new_symbol(char* name, variable_type_t type, int scope) {
    if (lookup_in_scope(name,scope) != NULL) {
        yyerror("Variable already declared");
        return NULL;
    } else {
        return insert_symbol(name,type,scope);
    }
}

/**
* Searches for the provided (symbol) name in the provided scope.
* If the symbol cannot be found in the provided scope, NULL is returned.
* If the symbol can be found, it is returned.
*/
symbol_t* lookup_in_scope(char* name, int scope) {
    int lookup_scope = scope;
    int h = hash(name);
    symbol_t* sym = symbol_table[h];

    while (lookup_scope > 0) {
        if (DEBUG_MODE) {
            printf(TEXT_COLOR_CYAN);
            printf("looking up %s (scope %d)\n", name, lookup_scope);
            printf(TEXT_COLOR_RESET);
        }

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

/**
* Searches for the provided (symbol) name in the provided scope.
* If the symbol cannot be found in the provided scope, the scope is reduced until it reaches 1.
* If the symbol can be found in lower scopes, it is returned. In other cases NULL is returned instead.
*/
symbol_t* lookup(char* name, int scope) {
    int lookup_scope = scope;
    int h = hash(name);
    symbol_t* sym = symbol_table[h];

    while (lookup_scope > 0) {
        if (DEBUG_MODE) {
            printf(TEXT_COLOR_CYAN);
            printf("looking up %s (scope %d)\n", name, lookup_scope);
            printf(TEXT_COLOR_RESET);
        }

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

/**
* Adds the provided symbol name and type to the symbol table indicating the provided scope ID.
*/
symbol_t* insert_symbol(char* name, variable_type_t type, int scope) {
    int h = hash(name);
    symbol_t* new_sym = malloc(sizeof(symbol_t));
    new_sym->name = strdup(name);
    new_sym->value.type = type;
    new_sym->scope_level = scope;
    new_sym->next = symbol_table[h];
    symbol_table[h] = new_sym;
    return new_sym;
}

/**
* Verifies if the value provided in val2 is compatible with the variable data type of val1.
* Throws an error if the types are incompatible.
*/
void verify_types_match(runtime_value_t val1, runtime_value_t val2) {
    if (val1.type != val2.type) {
        if (((val1.type == TYPE_INTEGER) && (val2.type == TYPE_DECIMAL)) || ((val1.type == TYPE_DECIMAL) && (val2.type == TYPE_INTEGER)))
            return; // types can be matched

        if (val1.type == TYPE_STRING)
            return; // types can be matched as val2 will be converted to string.

        yyerror("Type mismatch");
    }
}

/**
* Assigns the provided value val to the provided symbol sym.
* Before assigning the value, a type check is performed, which throws an error if 
* the value val is incompatible with the type of symbol sym.
*/
void assign_symbol(symbol_t *sym, runtime_value_t val) {
    verify_types_match(sym->value,val);
    sym->value = convert_to_type(val,sym->value.type);
}

/**
* Executes a printf function using the provided value val.
* If new_line is != 0, then a newline is appended at the end.
*/
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
            yyerror("Unsupported type for print");
    }
    if (new_line) {
        printf("\n");
    }
}

/**
* Adds the two run time values val1 and val2 together.
* Before adding the values, a type check is performed. If the value in val2 
* is not compatible with the value type of val1, then an error is thrown.
* If val1 is of type str, then a string concatenation is performed.
* If the operation was successful, the operation result is returned.
*/
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

/**
* This method can only be called on values val of type int or dec.
* It takes the numeric value of the value and returns the negative value of it.
* If a str value was proided, an error is thrown.
*/
runtime_value_t negate_expression(runtime_value_t val) {
    if (val.type == TYPE_STRING) {
        yyerror("Unsupported type for negation");
        return create_integer_value(0);
    }
    
    double numeric_val = get_numeric_value(val);
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_BLUE);
        printf("Negate: %f\n",numeric_val);
        printf(TEXT_COLOR_RESET);
    }
    if (val.type == TYPE_INTEGER) {
        return create_integer_value(-(int)numeric_val);
    }
    return create_decimal_value(-numeric_val);
}

/**
* Takes two operands val1 and val2 and executes the operation provided in op on them.
* If either val1 or val2 is of type str, an error is thrown.
* If both operands are of type int, the operation is done with the int-data type.
* In all other cases, the operation is done with the double-data type.
* The result of the operation with its data type is returned.
*/
runtime_value_t mathematical_operation(runtime_value_t val1, runtime_value_t val2, math_op_t op) {
    if (val1.type == TYPE_STRING || val2.type == TYPE_STRING) {
        yyerror("str type does not support this operation");
        return create_integer_value(0);
    }

    double num1 = get_numeric_value(val1);
    double num2 = get_numeric_value(val2);
    double result;

    // If both operands are integers, perform integer arithmetic
    // This is necessary for edge cases with maximum or minimum value integers, which
    // need to wrap around.
    if (val1.type == TYPE_INTEGER && val2.type == TYPE_INTEGER) {
        int int_result;
        switch(op) {
            case OP_ADDITION:
                int_result = (int)num1 + (int)num2;
                return create_integer_value(int_result);
            case OP_SUBTRACTION:
                int_result = (int)num1 - (int)num2;
                return create_integer_value(int_result);
            case OP_MULTIPLICATION:
                int_result = (int)num1 * (int)num2;
                return create_integer_value(int_result);
            case OP_DIVISION:
                if ((int)num2 == 0) {
                    yyerror("Division by zero");
                    return create_integer_value(0);
                }
                int_result = (int)num1 / (int)num2;
                return create_integer_value(int_result);
            default:
                yyerror("Unknown operation");
                return create_integer_value(0);
        }
    } else {
        // For decimal operations or mixed integer/decimal operations
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
    }
    
    return create_decimal_value(result);
}

/**
* Handles type conversion between the three data types.
* If the passed value val is already of the correct type, the value val is returned.
* In other cases the value is converted to the data type provided in new_type and returned.
*/
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

/**
* Creates a runtime_value_t using the provided int value.
*/
runtime_value_t create_integer_value(int value) {
    runtime_value_t result;
    result.type = TYPE_INTEGER;
    result.value.ival = value;
    return result;
}

/**
* Creates a runtime_value_t using the provided double value.
*/
runtime_value_t create_decimal_value(double value) {
    runtime_value_t result;
    result.type = TYPE_DECIMAL;
    result.value.dval = value;
    return result;
}


/**
* Creates a runtime_value_t using the provided char* value.
*/
runtime_value_t create_string_value(char* value) {
    runtime_value_t result;
    result.type = TYPE_STRING;
    result.value.sval = strdup(value);
    return result;
}

/**
* Returns a numeric value of type double from the provided value val.
* It is cast to double in case of integer.
*/
double get_numeric_value(runtime_value_t val) {
    if (val.type == TYPE_INTEGER) {
        return (double)val.value.ival;
    }
    return val.value.dval;
}

/**
* Converts the provided value val to string using the sprintf() function.
* In case of undefined strings, it returns the string literal "(undefined)".
*/
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
    yyerror("Conversion to string impossible");
    return NULL;
}

/**
* Compares the values val1 and val2 using the provided comparison operator op.
* If either va11 or val2 are of type string, then only the comparison operators == and != may be used.
* The result of the comparison is an integer value of 0 if the comparison is incorrect and 1 
* if the comparison is correct.
*/
runtime_value_t compare_expressions(runtime_value_t val1, runtime_value_t val2, math_op_t op) {
    if (val1.type == TYPE_STRING || val2.type == TYPE_STRING) {
        // Strings can only be compared in equality or inequality
        if (op != OP_EQUAL && op != OP_NOT_EQUAL) {
            yyerror("String comparison only supports == and !=");
            return create_integer_value(0);
        }
        
        char* str1 = get_string_value(val1);
        char* str2 = get_string_value(val2);
        int result = strcmp(str1, str2);
        
        switch(op) {
            case OP_EQUAL:
                return create_integer_value(result == 0);
            case OP_NOT_EQUAL:
                return create_integer_value(result != 0);
            default:
                return create_integer_value(0);
        }
    }
    
    double num1 = get_numeric_value(val1);
    double num2 = get_numeric_value(val2);
    int result;
    
    switch(op) {
        case OP_GREATER:
            result = num1 > num2;
            break;
        case OP_GREATER_EQUAL:
            result = num1 >= num2;
            break;
        case OP_LESS:
            result = num1 < num2;
            break;
        case OP_LESS_EQUAL:
            result = num1 <= num2;
            break;
        case OP_EQUAL:
            result = num1 == num2;
            break;
        case OP_NOT_EQUAL:
            result = num1 != num2;
            break;
        default:
            yyerror("Unknown comparison operator");
            return create_integer_value(0);
    }
    
    return create_integer_value(result);
}

/**
* Returns the integer 0 if the provided value is of numeric type and is 0.
* Returns the integer 0 if the provided value is of string type and is NULL. (undefined)
* Returns the integer 1 in all other cases.
*/
int expression_is_true(runtime_value_t val) {
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_MAGENTA);
        printf("Evaluating expression %d\n", val.value.ival);
        printf(TEXT_COLOR_RESET);
    }

    if (val.type == TYPE_STRING) {
        return val.value.sval != NULL;  // we return "true" if the stored string is not null
    } else {
        return get_numeric_value(val) != 0;
    }
}

/**
* Increments the if_condition_id by 1.
* Adds the result for an if condition to the if_condition_result stack.
*/
void add_if_condition(int result) {
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_MAGENTA);
        printf("Adding if-result to stack %d\n", result);
        printf(TEXT_COLOR_RESET);
    }

    if (if_condition_id < IF_TRACKER_SIZE) {
        if_condition_id++;
        if_condition_result[if_condition_id] = result;
    } else {
        yyerror("Too many nested ifs, cannot track any more");
    }
}

/**
* Decrements the if_condition_id by 1.
*/
void pop_if_condition() {
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_MAGENTA);
        printf("Popping if-result from stack\n");
        printf(TEXT_COLOR_RESET);
    }

    if (if_condition_id > 0) {
        if_condition_id--;
    } else {
        yyerror("No more if conditions to pop");
    }
}

/**
* Checks the current if_condition_result (stack) value.
* If the current if condition evaluated to 1, then this will return 1. (true)
* In other cases returns 0. (false)
*/
int should_execute_stmt() {
    return if_condition_result[if_condition_id];
}

/**
* Receives a string of form NdM in the variable dice_text.
* Also receives the modality of the roll in the variable roll_mod.
* This method calculates the number of dice to roll and their faces then calls
* the method roll_dice().
*/
runtime_value_t roll_dice_from_string(char* dice_text, dice_mod_t roll_mod) {
    int no_of_dice = 0;
    int no_of_faces = 0;
    char* d_pos = strchr(dice_text, 'd');
    if (!d_pos) {
        d_pos = strchr(dice_text, 'D');
    }
    
    if (!d_pos) {
        yyerror("Invalid dice notation");
        return create_integer_value(0);
    }
    
    // Parse number of dice
    char* end_ptr;
    no_of_dice = strtol(dice_text, &end_ptr, 10);
    if (end_ptr != d_pos || no_of_dice <= 0) {
        yyerror("Invalid number of dice");
        return create_integer_value(0);
    }
    
    // Parse number of faces
    no_of_faces = strtol(d_pos + 1, &end_ptr, 10);
    if (*end_ptr != '\0' || no_of_faces <= 0) {
        yyerror("Invalid number of faces");
        return create_integer_value(0);
    }
    
    return roll_dice(no_of_dice, no_of_faces, roll_mod);
}

/**
* Rolls the no_of_dice dices of no_of_faces faces with provided roll_mod modality.
* The rolled number is integer and is calculated using the rand() function.
* For rolls of ADV type, each roll is done twice and the better result is taken.
* For rolls of DADV type, each roll is done twice and the worse result is taken.
* Returns a value of type int with the combined value of rolled values.
*/
runtime_value_t roll_dice(int no_of_dice, int no_of_faces, dice_mod_t roll_mod) {
    if (DEBUG_MODE) {
        printf(TEXT_COLOR_BLUE);
        printf("Rolling %dd%d\n",no_of_dice,no_of_faces);
        printf(TEXT_COLOR_RESET);
    }
    int rolled_value = 0;
    for (int i = 0; i < no_of_dice; i++) {
        int curr_roll = rand() % no_of_faces + 1;
        if (DEBUG_MODE) {
            printf(TEXT_COLOR_BLUE);
            printf("Rolling 1d%d = %d\n",no_of_faces,curr_roll);
            printf(TEXT_COLOR_RESET);
        }
        int second_roll;
        if ((roll_mod == ROLL_W_ADV) || (roll_mod == ROLL_W_DADV)) {
            second_roll = rand() % no_of_faces + 1;
            if (DEBUG_MODE) {
                printf(TEXT_COLOR_BLUE);
                printf("Rolling another 1d%d = %d\n",no_of_faces,second_roll);
                printf(TEXT_COLOR_RESET);
            }
            if ((roll_mod == ROLL_W_ADV) && (second_roll > curr_roll)) {
                curr_roll = second_roll;
            } else if ((roll_mod == ROLL_W_DADV) && (second_roll < curr_roll)) {
                curr_roll = second_roll;
            }
        }
        rolled_value += curr_roll;
    }

    if (DEBUG_MODE) {
        printf(TEXT_COLOR_BLUE);
        printf("Result %d\n",rolled_value);
        printf(TEXT_COLOR_RESET);
    }

    return create_integer_value(rolled_value);
}

int main(void)
{
    // Initialize random seed with a combination of time and process ID for better entropy
    srand(time(0));
    // we start the if_condition_result stack with true, otherwise nothing is executed
    if_condition_result[if_condition_id] = 1;
    return yyparse();
}
