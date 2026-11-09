/*----------------------------------------------------------------
 *  libssl_standin.c
 *
 *  Changelog:
 *      Paulinchen  2026-10-30: Created
 *
 *----------------------------------------------------------------*/

/* The libssl.so the framework's library loads before its first crypto call on JoiPlay. Android
 * ships no libssl that an app may load, so .NET's crypto would abort the game; this library needs
 * the engine (libmkxp19.so), whose exported OpenSSL 3 .NET then finds through it. It adds only what
 * .NET requires but the engine lacks. */

/* .NET requires it to load, but the framework never checks OCSP; it fails as OpenSSL does. */
int OCSP_basic_verify(void* response, void* certificates, void* store, unsigned long flags)
{
    (void)response;
    (void)certificates;
    (void)store;
    (void)flags;
    return 0;
}

/* .NET requires it to load, but the framework never signs PKCS #7; it fails as OpenSSL does. */
void* PKCS7_sign(void* certificate, void* key, void* certificates, void* data, int flags)
{
    (void)certificate;
    (void)key;
    (void)certificates;
    (void)data;
    (void)flags;
    return 0;
}

/* The engine's OpenSSL 3 exports no version number, by which .NET picks its OpenSSL 3 calls. */
unsigned long OpenSSL_version_num(void)
{
    return 0x30000000UL;
}
