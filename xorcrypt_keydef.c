#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

// Key size fixed at compile time, override with: gcc -DKEY_SIZE=64 ...
// The key file must be exactly KEY_SIZE bytes long.
#ifndef KEY_SIZE
#define KEY_SIZE 32
#endif

void handle_error(const char *msg) {
    perror(msg);
    exit(EXIT_FAILURE);
}

// read() and write() may transfer fewer bytes than requested
// (and at most ~2GB per call), so loop until everything is done
void read_all(int fd, unsigned char *buf, size_t len, const char *msg) {
    size_t done = 0;
    while (done < len) {
        ssize_t n = read(fd, buf + done, len - done);
        if (n <= 0) {
            handle_error(msg);
        }
        done += n;
    }
}

void write_all(int fd, const unsigned char *buf, size_t len, const char *msg) {
    size_t done = 0;
    while (done < len) {
        ssize_t n = write(fd, buf + done, len - done);
        if (n <= 0) {
            handle_error(msg);
        }
        done += n;
    }
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <data_file> <key_file> <output_file>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    const char *data_file = argv[1];
    const char *key_file = argv[2];
    const char *output_file = argv[3];

    int data_fd, key_fd, output_fd;
    struct stat data_stat, key_stat;

    // Open data file
    data_fd = open(data_file, O_RDONLY);
    if (data_fd == -1) {
        handle_error("Failed to open data file");
    }

    // Get file size of data file
    if (fstat(data_fd, &data_stat) == -1) {
        handle_error("Failed to stat data file");
    }

    // Allocate memory for data buffer
    size_t data_size = data_stat.st_size;
    unsigned char *data_buffer = malloc(data_size ? data_size : 1);
    if (!data_buffer) {
        handle_error("Failed to allocate memory for data buffer");
    }

    // Read data file into buffer
    read_all(data_fd, data_buffer, data_size, "Failed to read data file");

    close(data_fd);

    // Open key file
    key_fd = open(key_file, O_RDONLY);
    if (key_fd == -1) {
        handle_error("Failed to open key file");
    }

    // Get file size of key file
    if (fstat(key_fd, &key_stat) == -1) {
        handle_error("Failed to stat key file");
    }

    // The key size is known at compile time, so the key lives on the stack
    if (key_stat.st_size != KEY_SIZE) {
        fprintf(stderr, "Key file must be exactly %d bytes (built with KEY_SIZE=%d)\n", KEY_SIZE, KEY_SIZE);
        exit(EXIT_FAILURE);
    }
    unsigned char key_buffer[KEY_SIZE];

    // Read key file into buffer
    read_all(key_fd, key_buffer, KEY_SIZE, "Failed to read key file");

    close(key_fd);

    // Perform XOR
    // Same blocked loop as xorcrypt.c, but KEY_SIZE is a constant, so the
    // compiler fully unrolls the inner loop into a fixed number of SIMD ops.
    // (key_buffer[i % KEY_SIZE] would still be ~5x slower, even with a constant.)
    size_t i = 0;
    for (; i + KEY_SIZE <= data_size; i += KEY_SIZE) {
        for (size_t j = 0; j < KEY_SIZE; ++j) {
            data_buffer[i + j] ^= key_buffer[j];
        }
    }
    // Leftover bytes when the data size isn't a multiple of the key size
    for (size_t j = 0; i < data_size; ++i, ++j) {
        data_buffer[i] ^= key_buffer[j];
    }

    // Open output file for writing
    output_fd = open(output_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (output_fd == -1) {
        handle_error("Failed to open output file");
    }

    // Write XORed data to output file
    write_all(output_fd, data_buffer, data_size, "Failed to write to output file");

    close(output_fd);
    free(data_buffer);

    printf("Encryption completed successfully.\n");
    return 0;
}
