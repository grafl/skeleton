# Local Apache HTTP Server testing (Windows)

The `httpd-server` CMake target builds Apache HTTP Server 2.4.71 from
`external\httpd`. It builds its own shared APR 1.7.6 and APR-util 1.6.6, plus
static Expat 2.10.0 and PCRE2 10.49, from the existing submodules. These are
isolated from the `skeleton` executable's static libraries; no system-wide
installation or Windows service is created.

## Build

Use PowerShell with CMake, Visual Studio's C++ build tools, and Perl available.
Git for Windows' bundled Perl is detected if Perl is not on `PATH`.

```powershell
git submodule update --init --recursive
cmake -S . -B build
cmake --build build --config Debug --target mod_test
```

The first build compiles all server dependencies. Its runnable installation is
`build\httpd\Debug`; use `Release` instead of `Debug` consistently to build and
run that configuration. A normal full build includes the server; configure
with `-DSKELETON_BUILD_HTTPD=OFF` to build only the existing application.

## Check and start

Run these commands from the repository root:

```powershell
$server = (Resolve-Path .\build\httpd\Debug).Path
$httpd = Join-Path $server 'bin\httpd.exe'
& $httpd -v
& $httpd -f "$server\conf\test-httpd.conf" -t
& $httpd -f "$server\conf\test-httpd.conf"
```

The last command stays in the foreground. In another terminal, open
`http://127.0.0.1:8080/` or request it with:

```powershell
curl.exe --fail --show-error http://127.0.0.1:8080/
```

Expect a page containing `Skeleton HTTP test server is running.` Stop the
foreground server with **Ctrl+C**. Do not use the installed default `httpd.conf`:
the separate `test-httpd.conf` binds only to loopback, uses port 8080, limits
access to local clients, and disables directory listings and `.htaccess`.
Do not expose this development configuration to a network.

## Build and use mod_test

The project's loadable module is `src\mod_test.c`. Build it with:

```powershell
cmake --build build --config Debug --target mod_test
```

This also builds the server and `test1`, and places `mod_test.so` in
`build\httpd\Debug\modules`. It links against the server's import library, not
the application's static APR libraries. Stop any running server before
rebuilding the module or library, since Windows locks loaded DLLs.

The test configuration loads the module automatically. Check and start it with:

```powershell
& $httpd -f "$server\conf\test-httpd.conf" -t
& $httpd -f "$server\conf\test-httpd.conf" -M
& $httpd -f "$server\conf\test-httpd.conf"
```

In another terminal:

```powershell
curl.exe --fail --show-error http://127.0.0.1:8080/test
curl.exe --head http://127.0.0.1:8080/test
curl.exe --include --request POST http://127.0.0.1:8080/test
```

`GET /test` responds with HTTP 200 and `mod_test is running.` as plain text.
`HEAD /test` returns the same headers without a body. Other methods return
HTTP 405 and an `Allow` header. The handler is assigned to the `/test` location,
including its subpaths; static files outside that location keep their normal
behavior.

The handler name is `test-handler`, the exported module symbol is
`test_module`, and `LoadModule test_module modules/mod_test.so` loads it.
The `mod_test` target is available when `SKELETON_BUILD_HTTPD` is enabled.

## Shared APR library: test1

`src\test1.c` implements a regular shared library (not an Apache module).
Its public API is in `include\test1.h`. To build it independently:

```powershell
cmake --build build --config Debug --target test1
```

The DLL is written to `build\httpd\Debug\bin\test1.dll`. Building `mod_test`
also builds `test1` automatically. The configuration loads it first:

```apache
LoadFile bin/test1.dll
LoadModule test_module modules/mod_test.so
```

`LoadFile` loads a plain shared library; `LoadModule` additionally registers an
Apache module. Do not use `LoadModule` for `test1`. It will not appear in
`httpd -M`, which lists Apache modules rather than all loaded DLLs.

`mod_test` calls `test1_message(r->pool)` to obtain its existing response
text. The library uses `apr_pstrdup` and the request's APR pool, so the returned
string is released when httpd destroys that pool. httpd owns APR initialization
and termination; the library must not initialize or terminate APR itself.

Both use the server's shared `libapr-1.dll`, not the application's static APR.
Keep each configuration's DLLs together and do not mix Debug and Release.
`test1` uses CMake's generated export header to export its API and import it
from `mod_test`. After rebuilding, restart the server to load the new DLLs.

## Use in future tests

Place static fixtures in `build\httpd\Debug\test-htdocs`, then point the
application or integration tests at `http://127.0.0.1:8080/`. For example:

```powershell
Set-Content "$server\test-htdocs\fixture.json" '{"ready":true}' -Encoding ascii
curl.exe --fail --show-error http://127.0.0.1:8080/fixture.json
curl.exe --silent --output NUL --write-out "%{http_code}" http://127.0.0.1:8080/missing
```

These endpoints allow testing successful downloads, JSON responses, missing
resources (404), and HTTP client behavior. This is a separate server process,
not an HTTP server embedded in `skeleton.exe`; it does not automatically test
application code or provide an application API.

For automation, start the executable using PowerShell `Start-Process -PassThru`
with arguments `-X -f "<absolute path to test-httpd.conf>"`. `-X` runs a single
server process, so there is no child process to leave behind. Poll an HTTP
endpoint until ready with a bounded timeout, run tests, and stop that specific
process in a `finally` block. Forced termination can leave a stale PID file
and produce an unclean-shutdown warning on the next run. Use a dedicated port
and server directory for parallel test jobs; never stop processes by name.

The test configuration enables HTTP/1.1 static hosting and `mod_test`; it does
not enable TLS, HTTP/2, CGI, or a reverse proxy. Those require additional
modules, dependencies, and explicit configuration. PCRE2 JIT is disabled;
regex matching uses the interpreter without requiring PCRE2's nested SLJIT
submodule.

## Configuration and troubleshooting

- The test configuration template is `cmake\httpd-test.conf.in`. Edit its
  `Listen` and `ServerName` together to change port, then regenerate the local
  configuration with:
  `cmake "-DHTTPD_TEST_ROOT:PATH=$server" -P .\cmake\PrepareHttpdTest.cmake`.
  This also resets the sample `index.html`; other fixtures are left untouched.
- Errors appear in `build\httpd\Debug\logs\test-error.log`. If port 8080 is
  occupied, stop your own server or choose another port; do not terminate
  unrelated processes.
- Keep the installation's `bin` directory together: `httpd.exe` needs its
  companion DLLs, and the configured modules live in `modules`.
- Dependency build directories are under `build\httpd-build`. CMake's external
  project step logs are under `build\<target>-prefix\src\<target>-stamp`.
- APR, APR-util, and httpd use upstream Windows CMake builds. Their legacy
  deprecation warnings do not indicate build failure; this setup is not a
  Unix/Linux build recipe.
