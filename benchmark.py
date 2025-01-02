import subprocess
import time
import statistics
import matplotlib.pyplot as plt
import numpy as np

programs = {
    "./xorcrypt_avx2": "red",
    "./xorcrypt_gpr": "green"
}

parameters = [
    "100MB",
    "1GB"
]

file_mapping = {
    "100MB": ["random_100MB.data", "key.bin", "blank.out"],
    "1GB": ["random_1GB.data", "key.bin", "blank.out"]
}

def benchmark(program, params, runs=10):
    times = []
    for _ in range(runs):
        start_time = time.time()
        subprocess.run([program] + params, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elapsed_time = time.time() - start_time
        times.append(elapsed_time)
    return statistics.median(times)

results = {param: {} for param in parameters}

for program, color in programs.items():
    for param in parameters:
        param_files = file_mapping[param]
        median_time = benchmark(program, param_files)
        results[param][program] = median_time
        print(f"Median time for {program} with {param}: {median_time:.4f} seconds")

bar_width = 0.35  # Width of each bar
indices = np.arange(len(parameters))  # Indices for parameter groups

avx2_times = [results[param]["./xorcrypt_avx2"] for param in parameters]
gpr_times = [results[param]["./xorcrypt_gpr"] for param in parameters]

plt.figure(figsize=(10, 6))
plt.bar(indices - bar_width / 2, avx2_times, bar_width, label="AVX2", color="red")
plt.bar(indices + bar_width / 2, gpr_times, bar_width, label="GPR", color="green")

plt.xticks(indices, parameters)
plt.xlabel("File Size")
plt.ylabel("Median Time (s)")
plt.title("Benchmark Results for AVX2 and GPR Variants")
plt.legend()
plt.tight_layout()

plt.show()
