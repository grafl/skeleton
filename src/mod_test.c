#include <string.h>

#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_request.h"

static int test_handler(request_rec *r) {
    static const char response[] = "mod_test is running.\n";
    if (r->handler == NULL || strcmp(r->handler, "test-handler") != 0) {
        return DECLINED;
    }
    ap_allow_methods(r, 1, "GET", "HEAD", NULL);
    if (r->method_number != M_GET) {
        return HTTP_METHOD_NOT_ALLOWED;
    }
    int status = ap_discard_request_body(r);
    if (status != OK) {
        return status;
    }
    ap_set_content_type(r, "text/plain; charset=utf-8");
    ap_set_content_length(r, sizeof(response) - 1);
    if (r->header_only) {
        return OK;
    }
    return ap_rputs(response, r) < 0 ? AP_FILTER_ERROR : OK;
}

static void test_register_hooks(apr_pool_t *pool) {
    ap_hook_handler(test_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

AP_DECLARE_MODULE(test) = {
    STANDARD20_MODULE_STUFF,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    test_register_hooks,
    AP_MODULE_FLAG_NONE
};
