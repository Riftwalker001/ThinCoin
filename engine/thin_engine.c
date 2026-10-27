#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <sys/time.h>

/*
 * ThinPoWToken (THIN) — Native Multi-Core C Engine
 * Sequential-64 Keccak-256 Mining Accelerator with Thermal & Multi-Threading Support.
 */

static const uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL, 0x8000000080008000ULL,
    0x000000000000808BULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008AULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
    0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800AULL, 0x800000008000000AULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
};

static const int ROT[5][5] = {
    {0, 36, 3, 41, 18},
    {1, 44, 10, 45, 2},
    {62, 6, 43, 15, 61},
    {28, 55, 25, 21, 56},
    {27, 20, 39, 8, 14}
};

static inline uint64_t rol64(uint64_t val, int shift) {
    return (val << shift) | (val >> (64 - shift));
}

static inline void keccak_f1600(uint64_t state[25]) {
    for (int r = 0; r < 24; r++) {
        uint64_t c[5];
        for (int x = 0; x < 5; x++) {
            c[x] = state[x] ^ state[x+5] ^ state[x+10] ^ state[x+15] ^ state[x+20];
        }

        uint64_t d[5];
        for (int x = 0; x < 5; x++) {
            d[x] = c[(x+4)%5] ^ rol64(c[(x+1)%5], 1);
        }

        for (int i = 0; i < 25; i++) {
            state[i] ^= d[i%5];
        }

        uint64_t b[25];
        for (int x = 0; x < 5; x++) {
            for (int y = 0; y < 5; y++) {
                b[y + 5 * ((2*x + 3*y)%5)] = rol64(state[x + 5*y], ROT[x][y]);
            }
        }

        for (int y = 0; y < 25; y += 5) {
            for (int x = 0; x < 5; x++) {
                state[y+x] = b[y+x] ^ ((~b[y + (x+1)%5]) & b[y + (x+2)%5]);
            }
        }

        state[0] ^= RC[r];
    }
}

static inline void keccak256_single_block(const uint8_t *in, size_t in_len, uint8_t out[32]) {
    uint64_t state[25] = {0};
    uint8_t block[136] = {0};
    memcpy(block, in, in_len);
    block[in_len] = 0x01;
    block[135] |= 0x80;

    for (int i = 0; i < 17; i++) {
        uint64_t lane = 0;
        memcpy(&lane, &block[i * 8], 8);
        state[i] ^= lane;
    }
    keccak_f1600(state);

    memcpy(out, state, 32);
}

void compute_sequential_digest(const uint8_t challenge[32], const uint8_t miner[20], uint64_t nonce, uint8_t out[32]) {
    uint8_t buf0[84];
    memcpy(buf0, challenge, 32);
    memcpy(buf0 + 32, miner, 20);
    memset(buf0 + 52, 0, 24);
    for (int i = 0; i < 8; i++) {
        buf0[83 - i] = (uint8_t)((nonce >> (i * 8)) & 0xFF);
    }

    uint8_t digest[32];
    keccak256_single_block(buf0, 84, digest);

    uint8_t step_buf[96];
    memcpy(step_buf + 32, challenge, 32);
    memset(step_buf + 64, 0, 32); // Sanitized zero-memset

    for (int step = 1; step < 64; step++) {
        memcpy(step_buf, digest, 32);
        step_buf[95] = (uint8_t)step;
        step_buf[94] = (uint8_t)(step >> 8);
        keccak256_single_block(step_buf, 96, digest);
    }
    memcpy(out, digest, 32);
}

typedef struct {
    const uint8_t *challenge;
    const uint8_t *miner;
    const uint8_t *target;
    uint64_t start_nonce;
    uint64_t end_nonce;
    int thread_id;
    int num_threads;
    volatile int *found_flag;
    uint64_t *found_nonce;
    uint8_t *out_digest;
    pthread_mutex_t *found_lock;
} WorkerArgs;

static void* search_worker(void *arg_ptr) {
    WorkerArgs *args = (WorkerArgs*)arg_ptr;
    uint8_t digest[32];
    uint64_t start = args->start_nonce + args->thread_id;
    uint64_t step = args->num_threads;
    uint64_t end = args->end_nonce;

    for (uint64_t n = start; n < end; n += step) {
        if (*(args->found_flag)) {
            break;
        }
        compute_sequential_digest(args->challenge, args->miner, n, digest);
        if (memcmp(digest, args->target, 32) <= 0) {
            pthread_mutex_lock(args->found_lock);
            if (!*(args->found_flag)) {
                *(args->found_flag) = 1;
                *(args->found_nonce) = n;
                memcpy(args->out_digest, digest, 32);
            }
            pthread_mutex_unlock(args->found_lock);
            break;
        }
    }
    return NULL;
}

int thin_mine_batch(
    const uint8_t challenge[32],
    const uint8_t miner[20],
    const uint8_t target[32],
    uint64_t start_nonce,
    uint64_t count,
    int num_threads,
    uint64_t *found_nonce,
    uint8_t out_digest[32]
) {
    if (num_threads < 1) num_threads = 1;
    if (num_threads > 16) num_threads = 16;

    volatile int found_flag = 0;
    pthread_mutex_t found_lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_t threads[16];
    WorkerArgs args[16];

    for (int i = 0; i < num_threads; i++) {
        args[i].challenge = challenge;
        args[i].miner = miner;
        args[i].target = target;
        args[i].start_nonce = start_nonce;
        args[i].end_nonce = start_nonce + count;
        args[i].thread_id = i;
        args[i].num_threads = num_threads;
        args[i].found_flag = &found_flag;
        args[i].found_nonce = found_nonce;
        args[i].out_digest = out_digest;
        args[i].found_lock = &found_lock;
        pthread_create(&threads[i], NULL, search_worker, &args[i]);
    }

    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }

    return found_flag;
}
