run:
	nasm -felf64 sudoku.asm
	ld.gold -s -static -o sudoku sudoku.o
	cat ./example_sudoku.txt | ./sudoku

test:
	nasm -felf64 sudoku.asm
	ld.gold -s -static -o sudoku sudoku.o
	cat ./example_sudoku.txt | ./sudoku | grep -qPz "^483921657\n967345821\n251876493\n548132976\n729564138\n136798245\n372689514\n814253769\n695417382\n" && echo "Matches known result"

build:
	nasm -felf64 sudoku.asm
	ld.gold -s -static -o sudoku sudoku.o
