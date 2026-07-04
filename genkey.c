/* ecc_keys.c
 *
 * Copyright (C) 2006-2020 wolfSSL Inc.
 *
 * This file is part of wolfSSL. (formerly known as CyaSSL)
 *
 * wolfSSL is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * wolfSSL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
 */

/*
./configure && make && sudo make install
gcc -lwolfssl -o ecc_pub ecc_pub.c
*/

#include "user_settings.h"
#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/wolfcrypt/ecc.h>
#include <wolfssl/wolfcrypt/asn_public.h>
#include <wolfssl/wolfcrypt/random.h>

#include <stdio.h>
#include <stdlib.h>

#define ECC_CURVE_SZ 32 /* SECP256R1 curve size in bytes */
#define ECC_CURVE_ID ECC_SECP256R1

#define MAX_DER_SZ 256

int main()
{
    int ret;
    ecc_key key;
    WC_RNG rng;
    byte der[MAX_DER_SZ*4];
    byte buf[MAX_DER_SZ*2];
    word32 idx;
    FILE *derFile;
    size_t sz;

    Cert cert;
    wc_InitCert(&cert);

    strncpy(cert.subject.commonName, "hello world", CTC_NAME_SIZE);

    wc_InitRng(&rng);
    wc_ecc_init(&key);

    ret = wc_ecc_make_key_ex(&rng, ECC_CURVE_SZ, &key, ECC_CURVE_ID);
    if (ret != 0)
    {
        printf("error %d making ecc key\n", ret);
        return ret;
    }

    /* write private key */
    ret = wc_EccKeyToDer(&key, der, sizeof(der));
    if (ret < 0)
    {
        printf("error %d in ecc to der\n", ret);
        return ret;
    }
    sz = ret;

    printf("writing private key to ecc-key.der (%d bytes)\n", (int)sz);

    byte pem[4096];

    int pemSz = wc_DerToPem(
        der, sz,
        pem, sizeof(pem),
        ECC_PRIVATEKEY_TYPE);
    if (pemSz < 0)
    {
        // error
    }

    // pem now contains a null-terminated PEM string.
    printf("%s\n", pem);

    ret = wc_MakeCert(&cert, buf, sizeof(buf), NULL, &key, &rng);
    if (ret < 0)
    {
        printf("error generating certificate: -%d\n", -ret);
        return -1;
    }

    ret = wc_SignCert(cert.bodySz, CTC_SHA256wECDSA,
                      buf, sizeof(buf), NULL, &key, &rng);

    if (ret < 0)
    {
        printf("error signing certificate: -%d\n", -ret);
        return -1;
    }

    ret = wc_DerToPem(buf, ret, der, sizeof(der), CERT_TYPE);

    if (ret < 0)
    {
        printf("error PEM certificate: -%d\n", -ret);
        return -1;
    }

    printf("\n%s\n", der);

    wc_ecc_free(&key);

    wc_ecc_free(&key);
    wc_FreeRng(&rng);
    return 0;
}