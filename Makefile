all:
	flex -l dnd-lex.l;
	yacc -vd dnd-compiler.y;
	gcc y.tab.c -ly -ll -o dnd-compiler.o
