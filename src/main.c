#include <stdio.h>
#include <string.h>

#include <apr_base64.h>
#include <apr_general.h>
#include <apr_pools.h>
#include <apr_strings.h>
#include <apr_version.h>

#include <apu_version.h>

#include "skeleton.h"

int main(void) {
    apr_status_t status = apr_initialize();
    if (status != APR_SUCCESS) {
        fprintf(stderr, "APR initialization failed: %d\n", (int)status);
        return 1;
    }

    apr_pool_t *pool = NULL;
    status = apr_pool_create(&pool, NULL);
    if (status != APR_SUCCESS) {
        fprintf(stderr, "APR pool creation failed: %d\n", (int)status);
        apr_terminate();
        return 1;
    }

    const char *name = apr_pstrdup(pool, SKELETON_TAG);
    if (name == NULL) {
        fprintf(stderr, "APR string allocation failed\n");
        apr_pool_destroy(pool);
        apr_terminate();
        return 1;
    }

    int encoded_capacity = apr_base64_encode_len((int)strlen(name));
    char *encoded_name = apr_palloc(pool, (apr_size_t)encoded_capacity);
    if (encoded_name == NULL) {
        fprintf(stderr, "APR-Util buffer allocation failed\n");
        apr_pool_destroy(pool);
        apr_terminate();
        return 1;
    }

    apr_base64_encode(encoded_name, name, (int)strlen(name));
    printf("%s - %s! (APR %s, APR/Util %s, Base64 %s)\n",
           name, SKELETON_VERSION, apr_version_string(), apu_version_string(), encoded_name);

    apr_pool_destroy(pool);
    apr_terminate();
    return 0;
}
