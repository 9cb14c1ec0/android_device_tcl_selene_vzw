/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * Symbols the Android 13 vendor wpa_supplicant/hostapd/hs20-osu-client
 * expect from libcrypto that Android 15 BoringSSL no longer exports.
 */

#include <stddef.h>
#include <stdint.h>

/* <openssl/stack.h>: sk_dup was renamed to OPENSSL_sk_dup (same semantics). */
typedef struct stack_st OPENSSL_STACK;
OPENSSL_STACK* OPENSSL_sk_dup(const OPENSSL_STACK* sk);

OPENSSL_STACK* sk_dup(const OPENSSL_STACK* sk) {
    return OPENSSL_sk_dup(sk);
}

/* <openssl/bytestring.h>: CBS_init became an inline function. */
typedef struct cbs_st {
    const uint8_t* data;
    size_t len;
} CBS;

void CBS_init(CBS* cbs, const uint8_t* data, size_t len) {
    cbs->data = data;
    cbs->len = len;
}
