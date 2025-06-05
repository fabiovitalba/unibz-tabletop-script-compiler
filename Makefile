all:
	flex -l tabletop-script-lex.l;
	bison -vd tabletop-script-compiler.y;
	gcc tabletop-script-compiler.tab.c -ly -ll -o tabletop-script-compiler.o
