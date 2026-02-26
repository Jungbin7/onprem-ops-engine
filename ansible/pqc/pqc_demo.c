#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <oqs/oqs.h>

/*
 * Post-Quantum Cryptography Demo: Kyber Key Encapsulation
 * Demonstrates securing payment data structure.
 */

int main() {
    OQS_STATUS rc;
    uint8_t *public_key = NULL;
    uint8_t *secret_key = NULL;
    uint8_t *ciphertext = NULL;
    uint8_t *shared_secret_e = NULL;
    uint8_t *shared_secret_d = NULL;

    const char *method_name = OQS_KEM_alg_kyber_512;
    OQS_KEM *kem = OQS_KEM_new(method_name);
    if (kem == NULL) {
        printf("KEM %s not supported.\n", method_name);
        return 1;
    }

    public_key = malloc(kem->length_public_key);
    secret_key = malloc(kem->length_secret_key);
    ciphertext = malloc(kem->length_ciphertext);
    shared_secret_e = malloc(kem->length_shared_secret);
    shared_secret_d = malloc(kem->length_shared_secret);

    printf("[PQC-DEMO] Starting Kyber-512 Key Exchange Simulation...\n");

    // 1. Generate Key Pair
    rc = OQS_KEM_keypair(kem, public_key, secret_key);
    if (rc != OQS_SUCCESS) { printf("Keypair failed\n"); return 1; }
    printf("[PQC-DEMO] Keypair generated successfully.\n");

    // 2. Encapsulate (Sender)
    rc = OQS_KEM_encaps(kem, ciphertext, shared_secret_e, public_key);
    if (rc != OQS_SUCCESS) { printf("Encapsulation failed\n"); return 1; }
    printf("[PQC-DEMO] Secret encapsulated in ciphertext.\n");

    // 3. Decapsulate (Receiver)
    rc = OQS_KEM_decaps(kem, shared_secret_d, ciphertext, secret_key);
    if (rc != OQS_SUCCESS) { printf("Decapsulation failed\n"); return 1; }
    printf("[PQC-DEMO] Secret decapsulated successfully.\n");

    // 4. Verify
    if (memcmp(shared_secret_e, shared_secret_d, kem->length_shared_secret) == 0) {
        printf("[PQC-DEMO] Verification SUCCESS: Shared secrets match!\n");
    } else {
        printf("[PQC-DEMO] Verification FAILED: Secrets do not match.\n");
    }

    free(public_key);
    free(secret_key);
    free(ciphertext);
    free(shared_secret_e);
    free(shared_secret_d);
    OQS_KEM_free(kem);

    return 0;
}
