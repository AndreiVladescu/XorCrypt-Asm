all: xorcrypt xorcrypt_C_O3 xorcrypt_C_O0

xorcrypt: xorcrypt.o
	ld xorcrypt.o -o xorcrypt
	
xorcrypt.o: xorcrypt.s
	nasm -f elf64 xorcrypt.s -o xorcrypt.o

xorcrypt_C_O0:
	gcc -O0 xorcrypt.c -o xorcrypt_C_O0

xorcrypt_C_O3:
	gcc -O3 xorcrypt.c -o xorcrypt_C_O3

clean:
	rm -f xorcrypt
	rm -f xorcrypt.o
	rm -f xorcrypt_C_O0
	rm -r xorcrypt_C_O3
