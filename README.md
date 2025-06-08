# Tabletop Script Compiler
This project is a compiler for a custom language designed for tabletop role-playing games like Dungeons and Dragons. It offers features for basic programming constructs and specialized dice rolling mechanics.

# Index
1. Language features
2. Compiler compilation
3. Running a program using the compiler

# 1. Language features
## 1.0 Language Building Blocks
Code is always contained in a **Block** which has its own scope. A block is declared using `{ }`.
Each line of code, inside a block, ends in `;`.

A sample structure looks like this:
```
{
    statement;
    statement;
    statement;
    ...
}
```

## 1.1 Data Types
The language offers three data types:
* `int`: which corresponds to the `int` datatype found in C.
* `dec`: which corresponds to the `double` datatype found in C.
* `str`: which corresponds to the `char*` datatype found in C.

## 1.2 Variable declarations
Variables need to be declared in a dedicated line of code. Value assignments in the variable declaration are not allowed.

Sample variable declarations include:
```
{
    int someInt;
    dec someDec;
    str someStr;
    ...
}
```

## 1.3 Expressions
Expressions contain several operators:
* `+`, `-`, `*`, `/`: Addition, subtraction, multiplication and division between numbers (`int` or `dec`).  
Expressions that affect numeric values are automatically cast to an appropriate type. Meaning that only if both operands are of type `int`, the result will be of type `int`. If one of the operands is of type `dec`, then the result will be of type `dec`.

* `+`: String concatenation if the left operand in an expression is of type `str`.

* `-` followed by a number (`int` or `dec`): Negates the numeric value.

* `<`, `<=`, `>`, `>=`, `==`, `!=`: Comparison operands used to compare numbers (`int` or `dec`).

* `==` or `!=`: Comparison operands for `str` comparison.

* `()`: Parentheses for grouping expressions and controlling operator precedence.

_See Variable assignment (1.4) for some samples._

## 1.4 Variable assignment
Variables need to be declared previously in order to be able to receive a value.
Value assignment is done through `=`.
The variable is defined at the left, whereas the value to be assigned is put to the right. You can use any expression to express a value for a variable.

Samples:
```
    int someInt;
    someInt = 5;

    dec someDec;
    someDec = 16.05;

    str someStr;
    someStr = "This is a string.";

    someInt = someInt * 5;      // someInt is now 25
    someInt = someInt / 2.0     // someInt is now 12

    someDec = 25;
    someDec = someDec / 2       // someDec is now 12.5
    someDec = someDec + 0.5;    // someDec is now 13.0

    someStr = "someDec: " + someDec; // someStr is "someDec: 13.0"

    // Using parentheses to control operator precedence
    someInt = (2 + 3) * 4;      // someInt is now 20
    someInt = 2 + (3 * 4);      // someInt is now 14
```

## 1.5 If Control statements
The language supports basic if statements for control flow. The syntax is similar to C:
```
if (condition) {
    statement;
    statement;
    ...
}
```

The condition can be any expression that evaluates to a boolean value:
* Numeric values: 0 is considered false, any other value is true
* String values: null/undefined strings are false, any other string is true
* Comparison expressions using `<`, `<=`, `>`, `>=`, `==`, `!=`

Sample:
```
if (myInt > 40) {
    prtln("myInt is greater than 40");
    myInt = myInt - 200;
}
```

## 1.6 Print functions
The language provides two print functions:
* `prt(expression)`: Prints the expression without a newline
* `prtln(expression)`: Prints the expression followed by a newline

Both functions can print any type of value (`int`, `dec`, or `str`). String concatenation can be used to combine multiple values:
```
prt("Value: " + myInt);
prtln("Decimal: " + myDec);
```

## 1.7 Nested scopes
The language supports nested scopes through blocks. Each block creates a new scope level where variables can be declared. Variables declared in an outer scope are accessible in inner scopes, but variables declared in an inner scope are not accessible in outer scopes.

Sample:
```
{
    int outerVar;
    outerVar = 10;
    
    {
        int innerVar;
        innerVar = 20;
        prtln(outerVar);  // Can access outerVar
    }
    
    prtln(innerVar);  // Error: innerVar is not accessible here
}
```

## 1.8 Dice Rolling
The language supports dice rolling expressions, which are useful for tabletop role-playing games. The syntax follows the standard dice notation format.

### 1.8.1 Basic Dice Rolling
Dice rolls are expressed using the format `NdM` where:
- `N` is the number of dice to roll
- `M` is the number of faces on each die

Sample:
```
{
    int rollResult;
    rollResult = 2d6;      // Rolls 2 six-sided dice
    rollResult = 1d20;     // Rolls 1 twenty-sided die
    rollResult = 3d8 + 2;  // Rolls 3 eight-sided dice and adds 2 to the result
}
```

### 1.8.2 Dice Rolling with Modifiers
The language supports two special dice rolling modifiers:
- `adv`: Rolls with advantage (rolls twice and takes the higher result)
- `dadv`: Rolls with disadvantage (rolls twice and takes the lower result)

Sample:
```
{
    int rollWithAdvantage;
    rollWithAdvantage = 1d20 adv;     // Rolls 1d20 with advantage
    rollWithAdvantage = 2d8 adv + 3;  // Rolls 2d8 with advantage and adds 3

    int rollWithDisadvantage;
    rollWithDisadvantage = 1d20 dadv;     // Rolls 1d20 with disadvantage
    rollWithDisadvantage = 3d6 dadv + 2;  // Rolls 3d6 with disadvantage and adds 2
}
```

The dice rolling results can be used in any expression, including variable assignments and print statements. The results are always of type `int`.

## 1.9 Comments
The language supports single-line comments using `//`:
```
// This is a comment
int myVar;  // This is also a comment
```

# 2. Compiler compilation
## 2.1 Using `flex` and `bison` to compile
The compiler is built using flex (lexical analyzer) and bison (parser generator). To compile the compiler:

1. Make sure you have flex and bison installed
2. Run `make` in the project directory
3. The compiler will be generated as `tabletop-script-compiler.o`

# 3. Running a program using the compiler
To run a program:

1. Write your program in a file with any extension (e.g., `program.tts`)
2. Run the compiler with your program file as input:
```
./tabletop-script-compiler.o < program.tts
```

The compiler will interpret and execute your program, printing any output to the console.

# 4. Sample Programs
The repository includes several sample programs in the `./samples/` folder:
- `sample_program.tts`: Basic examples of language features
- `edge_cases.tts`: Examples of edge cases and complex expressions
- `program_with_lexer_error.tts`: Example of a program with lexical analysis errors
- `program_with_var_type_error.tts`: Example of a program with variable type errors
- `program_with_wrong_syntax_error.tts`: Example of a program with syntax errors
- `program_with_scope_error.tts`: Example of a program with scope-related errors

# 5. Language Grammar
The following is the formal grammar of the language:

## 5.1 Program Structure
```
<program> → <block>

<block> → '{' <stmt_list> '}'

<stmt_list> → <statement>
            | <statement> <stmt_list>
            | <block>
            | <block> <stmt_list>

<statement> → <declaration> ';'
            | <assignment> ';'
            | <function_exec> ';'
            | IF '(' <expression> ')' <block>
```

## 5.2 Declarations and Assignments
```
<declaration> → INT ID
              | DEC ID
              | STR ID

<assignment> → ID '=' <expression>
```

## 5.3 Expressions
```
<expression> → INT_LITERAL
             | DEC_LITERAL
             | STR_LITERAL
             | DICE
             | DICE ADV
             | DICE DADV
             | ID
             | '(' <expression> ')'
             | '-' <expression>
             | <expression> EQ <expression>
             | <expression> NEQ <expression>
             | <expression> GT <expression>
             | <expression> GTOE <expression>
             | <expression> LT <expression>
             | <expression> LTOE <expression>
             | <expression> '+' <expression>
             | <expression> '-' <expression>
             | <expression> '*' <expression>
             | <expression> '/' <expression>
```

## 5.4 Function Calls
```
<function_exec> → PRINT '(' <expression> ')'
                | PRINTLN '(' <expression> ')'
```

## 5.5 Regular Definitions
```
INT         → "int"
DEC         → "dec"
STR         → "str"
IF          → "if"
PRINT       → "prt"
PRINTLN     → "prtln"
ADV         → "adv"
DADV        → "dadv"
GT          → ">"
GTOE        → ">="
LT          → "<"
LTOE        → "<="
EQ          → "=="
NEQ         → "!="
INT_LITERAL → [0-9]+
DEC_LITERAL → [0-9]+.[0-9]+
STR_LITERAL → "[^"]*"
DICE        → [0-9]+[dD][0-9]+
ID          → [a-zA-Z_][a-zA-Z0-9_]*
```

## 5.6 Operator Precedence
The following precedence rules apply (from highest to lowest):
1. Parentheses `()`
2. Unary minus `-`
3. Equality operators `==`, `!=`
4. Comparison operators `<`, `<=`, `>`, `>=`
5. Multiplication `*` and division `/`
6. Addition `+` and subtraction `-`

## 5.7 Type Conversion Rules
1. If both operands are `int`, the result is `int`
2. If one operand is `dec`, the result is `dec`
3. If the left operand is `str`, string concatenation is performed
4. Comparison operators return `int` (1 for true, 0 for false)
5. Dice rolls always return `int`
