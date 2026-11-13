#include <apr_strings.h>

#include "test1.h"

const char *test1_message(apr_pool_t *pool) {
    return apr_pstrdup(pool, "libtest1 is running.\n");
}
