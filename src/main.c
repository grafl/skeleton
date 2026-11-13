#include <stdio.h>

#include <apr_general.h>
#include <apr_pools.h>
#include <apr_strings.h>
#include <apr_version.h>

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

    const char *name = apr_pstrdup(pool, "Skeleton");
    if (name == NULL) {
        fprintf(stderr, "APR string allocation failed\n");
        apr_pool_destroy(pool);
        apr_terminate();
        return 1;
    }

    printf("%s - %s! (APR %s)\n", name, SKELETON_VERSION, apr_version_string());

    apr_pool_destroy(pool);
    apr_terminate();
    return 0;
}
