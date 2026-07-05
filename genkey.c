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

int write_file(const char *filename, byte *data, size_t sz)
{
    FILE *derFile;

    derFile = fopen(filename, "w");
    if (!derFile)
    {
        printf("error opening file\n");
        return -1;
    }

    fwrite(data, 1, sz, derFile);
    fclose(derFile);

    return 0;
}

int main(int argc, char *argv[])
{
    int ret;
    ecc_key key;
    WC_RNG rng;
    Cert cert;
    byte buf[MAX_DER_SZ * 2];
    byte pem[MAX_DER_SZ * 4];

    wc_InitRng(&rng);
    wc_ecc_init(&key);
    wc_InitCert(&cert);

    if (argc > 1)
    {
        strncpy(cert.subject.commonName, argv[1], CTC_NAME_SIZE);
    }
    cert.daysValid = 365 * 9;

    ret = wc_ecc_make_key_ex(&rng, ECC_CURVE_SZ, &key, ECC_CURVE_ID);
    if (ret != 0)
    {
        printf("error %d making ecc key\n", ret);
        return ret;
    }

    ret = wc_EccKeyToDer(&key, buf, sizeof(buf));
    if (ret < 0)
    {
        printf("error %d in ecc to der\n", ret);
        return ret;
    }

    ret = wc_DerToPem(
        buf, ret,
        pem, sizeof(pem),
        ECC_PRIVATEKEY_TYPE);
    if (ret < 0)
    {
        printf("error converting key: -%d\n", -ret);
        return -1;
    }

    ret = write_file("key.pem", pem, ret);
    if (ret < 0)
    {
        printf("error in writing key.pem: -%d\n", -ret);
        return -1;
    }

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

    ret = wc_DerToPem(buf, ret, pem, sizeof(pem), CERT_TYPE);

    if (ret < 0)
    {
        printf("error PEM certificate: -%d\n", -ret);
        return -1;
    }

    ret = write_file("cert.pem", pem, ret);
    if (ret < 0)
    {
        printf("error in writing key.pem: -%d\n", -ret);
        return -1;
    }

    wc_ForceZero(&cert, sizeof(Cert));
    wc_ecc_free(&key);
    wc_FreeRng(&rng);
    return 0;
}