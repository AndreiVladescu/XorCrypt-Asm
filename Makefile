all: xorcrypt

xorcrypt: xorcrypt.o
	ld xorcrypt.o -o xorcrypt
	
xorcrypt.o: xorcrypt.s
	nasm -f elf64 xorcrypt.s -o xorcrypt.o

clean:
	rm -f xorcrypt
	rm -f xorcrypt.o