#ifndef TEST1_H
#define TEST1_H

#include <apr_pools.h>

#include "test1_export.h"

/* The returned string belongs to pool. */
TEST1_EXPORT const char *test1_message(apr_pool_t *pool);

#endif
