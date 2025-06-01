all:
	flex -l dnd-lex.l;
	bison -vd dnd-compiler.y;
	gcc dnd-compiler.tab.c -ly -ll -o dnd-compiler.o
