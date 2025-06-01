# Mini-c language compiler
This project is a very basic compiler for a subset of the C programming language.
It offers very limited functionality in the programs it interprets.

# Index
1. Language features

# 1. Language features
## 1.0 Language Building Blocks
Mini-c code is always contained in a **Block** which has its own scope. A block is declared using `{ }`.
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
Expressions containe a few operators:
* `+`, `-`, `*`, `/`: Addition, subtraction, multiplication and division between numbers (`int` or `dec`).  
Expressions that affect numeric values are automatically cast to an apropriate type. Meaning that only if both operands are of type `int`, the result will be of type `int`. If one the operands is of type `dec`, then the result will be of type `dec`.

* `+`: String concatenation if the left operand in an expression is of type `str`.

* `-` followed by a number (`int` or `dec`): Negates the numeric value.

* `<`, `<=`, `>`, `>=`, `==`, `!=`: Comparison operands used to compare numbers (`int` or `dec`).

* `==` or `!=`: Comparison operands for `str` comparison.

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
```

