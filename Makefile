run:
	nasm -felf64 sudoku.asm
	ld.gold -s -static -o sudoku sudoku.o
	cat ./example_sudoku.txt | ./sudoku

build:
	nasm -felf64 sudoku.asm
	ld.gold -s -static -o sudoku sudoku.o
