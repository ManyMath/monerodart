#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>


/**
 * Generates an address from a mnemonic
 */
const char *generate_address(const char *mnemonic,
                             uint8_t network,
                             uint32_t account,
                             uint32_t index);

/**
 * Generates a mnemonic in the specified language
 */
const char *generate_mnemonic(uint8_t language);
