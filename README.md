
# XorCrypt-Asm

  
This program XORs an input file with a key and writes it into an output file, on Linux x64 architecture.


## Usage

Ensure you have an assembler like `nasm` and a linker like `ld` installed and you're running an x64 Linux machine. Virtualbox VM is tested and works too, but there are some problems which are explained below. 

```bash
make && \
./xorcrypt data.dat key.bin data.out
```
To enable YMM or disable it, comment one of the lines:
```asm
    call fn_xor_buf
    call fn_xor_buf_ymm
```

## How it works

The program can be used in 2 modes:
- Byte-by-byte XOR-ing basis 
- AVX2 256 bits YMM operations

The byte-by-byte, while slower, has a key-wrapping feature, where if the key is smaller than the data file, it will wrap itself around it so it can XOR all the bytes. Also, it works with files that don't divide by 32 bytes.

The YMM version is a lot faster (benchmarks below), since it uses vector operations, `vmovqda` but is not yet patched to work with non-divisible sizes.

The memory is dynamically allocated using mmap.
  
## VirtualBox VM Setup

To see if your VM has  AVX2 enabled:
```bash
cat /proc/cpuinfo | grep avx
```
If AVX is enabled, it should return something. Also, make sure your CPU is new enough so it supports AVX2.

For me, VirtualBox didn't implement the AVX2 registers (Ryzen 7 5700X), so I had to enter these commands in CMD/Powershell, however I am **not** responsible if this messes up your environment:  
* Open CMD/Powershell using admin rights
* `bcdedit /set hypervisorlaunchtype off`
* `DISM /Online /Disable-Feature:Microsoft-Hyper-V`
* Restart the PC and it should detect it using `cat /proc/cpuinfo | grep avx`

## Benchmark
coming soon
