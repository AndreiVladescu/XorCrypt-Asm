CC = gcc
NASM = nasm
# Key size baked into xorcrypt_C_keydef, must match the size of the key file
KEY_SIZE ?= 32

BINS = xorcrypt xorcrypt_avx2 xorcrypt_gpr xorcrypt_noxor \
       xorcrypt_C_O0 xorcrypt_C_O3 xorcrypt_C_keydef

all: $(BINS)

# Assembly variants, selected with -D flags in xorcrypt.s
xorcrypt: xorcrypt_avx2
	cp $< $@

xorcrypt_avx2: xorcrypt.s
	$(NASM) -f elf64 $< -o $@.o
	ld $@.o -o $@

xorcrypt_gpr: xorcrypt.s
	$(NASM) -f elf64 -DUSE_GPR $< -o $@.o
	ld $@.o -o $@

# No XOR, only reads and writes the files: the I/O baseline for the benchmark
xorcrypt_noxor: xorcrypt.s
	$(NASM) -f elf64 -DNO_XOR $< -o $@.o
	ld $@.o -o $@

# C variants. -march=native lets gcc use AVX2 like the assembly version does
xorcrypt_C_O0: xorcrypt.c
	$(CC) -O0 $< -o $@

xorcrypt_C_O3: xorcrypt.c
	$(CC) -O3 -march=native $< -o $@

xorcrypt_C_keydef: xorcrypt_keydef.c
	$(CC) -O3 -march=native -DKEY_SIZE=$(KEY_SIZE) $< -o $@

clean:
	rm -f $(BINS) *.o

.PHONY: all clean
