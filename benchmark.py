import hashlib
import os
import subprocess
import statistics
import sys
import time

import matplotlib.pyplot as plt
import numpy as np

# Build everything with `make` first
programs = {
    "./xorcrypt_noxor": ("I/O only (no XOR)", "#BDBDBD"),  # Grey
    "./xorcrypt_avx2": ("ASM AVX2", "#FF6F61"),  # Coral Red
    "./xorcrypt_gpr": ("ASM GPR", "#6BAED6"),  # Sky Blue
    "./xorcrypt_C_O0": ("C -O0", "#C7E9C0"),  # Light Green
    "./xorcrypt_C_O3": ("C -O3", "#D95F02"),  # Orange
    "./xorcrypt_C_keydef": ("C -O3 KEY_SIZE define", "#7570B3"),  # Purple
}

sizes = {
    "100MB": ("random_100MB.data", 100 * 1024 * 1024),
    "1GB": ("random_1GB.data", 1000 * 1024 * 1024),
}

key_file = "key.bin"
out_file = "blank.out"
runs = 10


def make_test_file(path, size):
    # Same as: dd if=/dev/urandom of=<path> bs=1M count=<size in MB>
    if os.path.exists(path) and os.path.getsize(path) == size:
        return
    print(f"Generating {path}...")
    with open(path, "wb") as f:
        for _ in range(size // (1024 * 1024)):
            f.write(os.urandom(1024 * 1024))


def expected_hash(data_path, key):
    # Reference XOR in numpy, in chunks that are a multiple of the key length
    # so the key lines up at the start of every chunk
    h = hashlib.sha256()
    key_arr = np.frombuffer(key, dtype=np.uint8)
    chunk = len(key) * (4 * 1024 * 1024)
    with open(data_path, "rb") as f:
        while block := f.read(chunk):
            data = np.frombuffer(block, dtype=np.uint8)
            h.update((data ^ np.resize(key_arr, len(data))).tobytes())
    return h.hexdigest()


def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(16 * 1024 * 1024):
            h.update(block)
    return h.hexdigest()


def run(program, data_path):
    start = time.perf_counter()
    result = subprocess.run([program, data_path, key_file, out_file],
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    elapsed = time.perf_counter() - start
    if result.returncode != 0:
        sys.exit(f"{program} failed: {result.stderr.decode().strip()}")
    return elapsed


def benchmark(program, data_path, expected):
    # Warm-up run, also used to check that the program produces the right output.
    # A fast wrong answer is not a benchmark result.
    run(program, data_path)
    if expected is not None and file_hash(out_file) != expected:
        sys.exit(f"{program} produced WRONG output for {data_path}")
    return statistics.median(run(program, data_path) for _ in range(runs))


for program in programs:
    if not os.path.exists(program):
        sys.exit(f"{program} not found, run `make` first")

with open(key_file, "rb") as f:
    key = f.read()

results = {size: {} for size in sizes}

for size, (data_path, byte_count) in sizes.items():
    make_test_file(data_path, byte_count)
    expected = expected_hash(data_path, key)
    for program, (label, _) in programs.items():
        # The no-XOR baseline copies the input unchanged, so don't verify it
        check = None if program == "./xorcrypt_noxor" else expected
        median_time = benchmark(program, data_path, check)
        results[size][program] = median_time
        print(f"Median time for {label:22s} with {size}: {median_time:.4f} seconds")

os.remove(out_file)

bar_width = 0.8 / len(programs)  # Width of each bar
indices = np.arange(len(sizes))  # Indices for size groups

plt.figure(figsize=(12, 6))

for n, (program, (label, color)) in enumerate(programs.items()):
    offset = (n - (len(programs) - 1) / 2) * bar_width
    times = [results[size][program] for size in sizes]
    plt.bar(indices + offset, times, bar_width, label=label, color=color)

# Formatting the chart
plt.xticks(indices, list(sizes))
plt.xlabel("File Size")
plt.ylabel("Median Time (s)")
plt.title("XorCrypt benchmark (whole program: read + XOR + write)")
plt.legend()
plt.tight_layout()

plt.savefig("benchmark.png")
plt.show()
