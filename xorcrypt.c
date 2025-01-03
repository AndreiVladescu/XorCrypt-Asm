#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

void handle_error(const char *msg) {
    perror(msg);
    exit(EXIT_FAILURE);
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
    unsigned char *data_buffer = malloc(data_size);
    if (!data_buffer) {
        handle_error("Failed to allocate memory for data buffer");
    }

    // Read data file into buffer
    if (read(data_fd, data_buffer, data_size) != data_size) {
        handle_error("Failed to read data file");
    }

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

    // Allocate memory for key buffer
    size_t key_size = key_stat.st_size;
    unsigned char *key_buffer = malloc(key_size);
    if (!key_buffer) {
        handle_error("Failed to allocate memory for key buffer");
    }

    // Read key file into buffer
    if (read(key_fd, key_buffer, key_size) != key_size) {
        handle_error("Failed to read key file");
    }

    close(key_fd);

    // Perform XOR
    for (size_t i = 0; i < data_size; ++i) {
        data_buffer[i] ^= key_buffer[i % key_size];
    }

    free(key_buffer);

    // Open output file for writing
    output_fd = open(output_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (output_fd == -1) {
        handle_error("Failed to open output file");
    }

    // Write XORed data to output file
    if (write(output_fd, data_buffer, data_size) != data_size) {
        handle_error("Failed to write to output file");
    }

    close(output_fd);
    free(data_buffer);

    printf("Encryption completed successfully.\n");
    return 0;
}
