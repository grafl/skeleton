# Skeleton

A Windows-focused C17 project demonstrating Apache Portable Runtime (APR),
APR-util, and a custom Apache HTTP Server module. Project version: **0.0.1**.

The project has two separate execution paths:

- `skeleton.exe`: a console application using statically linked APR and APR-util.
- `httpd.exe`: a local web server loading `test1.dll` and `mod_test.so`, which
  use the server's shared APR.

This is a development and integration-testing skeleton, not a production web
application. The console application does not start or embed the web server.

## Architecture

| Component | Source | Responsibility |
| --- | --- | --- |
| `skeleton` | `src\main.c` | Initializes APR, creates a memory pool, Base64-encodes the project name with APR-util, prints versions, and cleans up. |
| `test1` | `src\test1.c`, `include\test1.h` | Exports `test1_message(apr_pool_t *)`, allocating a response using `apr_pstrdup`. |
| `mod_test` | `src\mod_test.c` | Registers Apache's `test-handler`, calls `test1_message` with the request pool, and returns a plain-text HTTP response. |
| `httpd-server` | `cmake\BuildHttpd.cmake` | Builds and stages Apache and its dependencies using isolated CMake external projects. |

The server-side request flow is:

```text
HTTP client -> httpd -> mod_test.so -> test1.dll -> shared libapr-1.dll
```

Apache initializes and terminates APR. The library uses the pool supplied by
Apache; the returned string remains valid until that pool is destroyed.
`test1` must not initialize or terminate APR on its own.

The test configuration explicitly loads the plain shared library before the
Apache module:

```apache
LoadFile bin/test1.dll
LoadModule test_module modules/mod_test.so
```

`LoadFile` loads a DLL; `LoadModule` additionally registers an Apache module.
Consequently, `httpd -M` lists `test_module`, but not `test1`.

## Dependencies and prerequisites

Use Windows with:

- Visual Studio's C++ build tools and Windows SDK, with a C17-capable MSVC.
- CMake **3.17 or newer**. The root declares 3.15, but bundled Expat requires
  3.17. Modern CMake is supported through compatibility settings for legacy APR
  build scripts.
- Git to obtain the dependencies.
- Perl for the httpd installation steps. The build also looks for Perl bundled
  with Git for Windows.
- PowerShell for the examples below; `curl.exe` for HTTP checks.

The checked-out dependency tags are:

| Dependency | Directory | Tag | Use |
| --- | --- | --- | --- |
| [APR](https://github.com/apache/apr) | `external\apr` | `1.7.6` | Pools, allocation, and platform services. |
| [APR-util](https://github.com/apache/apr-util) | `external\apr-util` | `1.6.6` | Base64 support and httpd utilities. |
| [Expat](https://github.com/libexpat/libexpat) | `external\expat` | `R_2_10_0` | APR-util's XML dependency. |
| [PCRE2](https://github.com/PCRE2Project/pcre2) | `external\pcre2` | `pcre2-10.49` | httpd's regular-expression support. |
| [Apache HTTP Server](https://github.com/apache/httpd) | `external\httpd` | `2.4.71` | Local server and module API. |

### Dependency checkout caveat

This snapshot tracks `.gitmodules`, but its Git index has no submodule gitlink
entries for the dependency directories, and `.gitignore` ignores `external\`.
The dependencies are present locally, but a fresh clone must not assume that
`git submodule update --init --recursive` alone will populate them.

Restore their submodule registration, or provision the source directories
explicitly. For a checkout where those directories do **not** already exist:

```powershell
git clone --branch 1.7.6 --depth 1 https://github.com/apache/apr.git .\external\apr
git clone --branch 1.6.6 --depth 1 https://github.com/apache/apr-util.git .\external\apr-util
git clone --branch R_2_10_0 --depth 1 https://github.com/libexpat/libexpat.git .\external\expat
git clone --branch pcre2-10.49 --depth 1 https://github.com/PCRE2Project/pcre2.git .\external\pcre2
git clone --branch 2.4.71 --depth 1 https://github.com/apache/httpd.git .\external\httpd
```

These commands provision sources, not parent-repository submodule tracking.
PCRE2 JIT is disabled, so the server build does not require its nested SLJIT
submodule.

## Build

Run commands from the project root. With the Visual Studio generator:

```powershell
cmake -S . -B build
cmake --build build --config Debug --parallel 4
```

The default build includes the console program, server, shared library, and
module. To build selected components:

| Command | Result |
| --- | --- |
| `cmake --build build --config Debug --target skeleton` | Console application and its static dependencies. |
| `cmake --build build --config Debug --target httpd-server` | Staged upstream server and dependencies, but not the project's DLL/module. |
| `cmake --build build --config Debug --target test1` | Server dependencies and `test1.dll`. |
| `cmake --build build --config Debug --target mod_test` | Complete custom server runtime, including `test1.dll` and `mod_test.so`. |

**Build `mod_test` before using `test-httpd.conf`**, since that configuration
unconditionally loads both custom binaries.

For an application-only build without the server, module, or shared library:

```powershell
cmake -S . -B build-app -DSKELETON_BUILD_HTTPD=OFF
cmake --build build-app --config Debug --target skeleton
```

Replace `Debug` consistently with `Release` for release builds. The documented
output paths assume a multi-configuration Visual Studio generator; the
server's external build directories and installations are configuration-specific.
Do not mix DLLs and import libraries from different configurations.

### Output locations

| Artifact | Debug location |
| --- | --- |
| Console executable | `build\Debug\skeleton.exe` |
| Server executable | `build\httpd\Debug\bin\httpd.exe` |
| Shared library | `build\httpd\Debug\bin\test1.dll` |
| Apache module | `build\httpd\Debug\modules\mod_test.so` |
| Generated library export header | `build\include\test1_export.h` |
| Test configuration | `build\httpd\Debug\conf\test-httpd.conf` |
| Static HTTP fixtures | `build\httpd\Debug\test-htdocs` |
| Server error log | `build\httpd\Debug\logs\test-error.log` |

Although its filename ends in `.so`, `mod_test` is a Windows loadable module.
The runtime is staged within the build tree; no system-wide server installation
or Windows service is created.

## Run the console application

```powershell
.\build\Debug\skeleton.exe
```

With the checked-out versions and current project constants, its output is:

```text
Skeleton - 0.0.1! (APR 1.7.6, APR/Util 1.6.6, Base64 U2tlbGV0b24=)
```

The display name and application version are defined in `include\skeleton.h`.
The CMake project version is separately declared in `CMakeLists.txt`.

## Run the web server

After building `mod_test`:

```powershell
$server = (Resolve-Path .\build\httpd\Debug).Path
$httpd = Join-Path $server 'bin\httpd.exe'
& $httpd -f "$server\conf\test-httpd.conf" -t
& $httpd -f "$server\conf\test-httpd.conf" -M
& $httpd -f "$server\conf\test-httpd.conf"
```

The last command runs in the foreground; stop it with **Ctrl+C**. In a separate
terminal:

```powershell
curl.exe --fail --show-error http://127.0.0.1:8080/
curl.exe --fail --show-error http://127.0.0.1:8080/test
curl.exe --head http://127.0.0.1:8080/test
curl.exe --include --request POST http://127.0.0.1:8080/test
```

| Endpoint | Current behavior |
| --- | --- |
| `/` | Serves the sample page containing `Skeleton HTTP test server is running.` |
| `/test` and its subpaths | Uses `test-handler`. GET returns HTTP 200; HEAD returns headers without a body; other methods return HTTP 405 with an `Allow` header. |
| `/server-info` | Uses Apache's `mod_info` handler to expose server configuration information for local diagnostics. |
| Other paths | Serve fixtures from `test-htdocs`, or return 404 if missing. |

The **current source** returns `libtest1 is running.` followed by a newline
from `/test`. Despite that literal message, the library and CMake target are
named **`test1`**, and the DLL is **`test1.dll`**.

The test server listens only on `127.0.0.1:8080`. Its document root allows local
clients, denies access outside that root by default, disables directory
listings, and ignores `.htaccess`. Treat this as a local development
configuration, especially with `/server-info` enabled. Do not expose it to a
network or substitute the installed default `httpd.conf`.

TLS and HTTP/2 modules are explicitly disabled for this build. The test
configuration does not set up CGI or proxy routes.

## Build-system design

The application and web-server paths intentionally use different APR builds:

1. The root CMake project adds APR, Expat, and APR-util in-tree. `skeleton`
   links the `aprutil-1` and `apr-1` static targets. `cmake\FindEXPAT.cmake`
   supplies the local Expat target to APR-util's legacy build.
2. `cmake\BuildHttpd.cmake` uses `ExternalProject` to build shared APR and
   APR-util plus static Expat and PCRE2, then builds and installs httpd.
   This also avoids upstream target-name collisions with the in-tree builds.
3. `test1` links the staged server APR import library. `mod_test` links `test1`
   and httpd's import library. They must use the server's APR DLL, not the
   console application's static APR, when sharing request pools.

The root build temporarily creates an APR library-check placeholder to satisfy
APR-util's configure-time file check. It then removes that placeholder from
the target's link properties and connects APR-util to the actual in-tree APR
target. The placeholder is not a runtime dependency.

`GenerateExportHeader` generates `test1_export.h` for the shared-library API.
Do not edit this generated header.

`cmake\InstallHttpd.cmake` adds the detected Perl directory to the install
process's `PATH`. `cmake\PrepareHttpdTest.cmake` creates the local fixture
directory and renders the configuration and sample page from templates.

## Development and testing

There is currently no project-owned automated test suite or registered CTest
suite. The build disables upstream test builds by default; the commands above
are manual smoke checks, not a full test suite.

Use additional files in `build\httpd\Debug\test-htdocs` as static fixtures.
For automated integration checks, start a dedicated server, wait for a ready
endpoint with a bounded timeout, run requests, and stop only the process you
started. Apache's `-X` option is useful for single-process testing.

Stop the server before rebuilding `test1` or `mod_test`: Windows locks loaded
DLLs. Detailed fixture, startup, and shutdown examples are in
[HTTPD_TESTING.md](HTTPD_TESTING.md); the response text above reflects the
current implementation in `src\test1.c`.

### Configuration and troubleshooting

- Edit `cmake\httpd-test.conf.in`, rather than treating the generated
  configuration as the source of truth. To regenerate it explicitly:
  `cmake "-DHTTPD_TEST_ROOT:PATH=$server" -P .\cmake\PrepareHttpdTest.cmake`.
  This also resets the sample `index.html`, but leaves other fixtures alone.
- If port 8080 is occupied, choose a different `Listen` and `ServerName` in the
  template. Do not terminate an unrelated server.
- Keep the staged `bin` and `modules` directories together. Missing
  `test1.dll`, APR DLLs, or a configuration mismatch can prevent module loading.
- External build trees are under `build\httpd-build\<target>\<configuration>`.
  Step logs are under `build\<target>-prefix\src\<target>-stamp`.
- APR and APR-util may emit upstream CMake deprecation warnings. A cached
  compiler path can also become invalid after a Visual Studio update; use a
  new build directory if necessary.
- `SKELETON_BUILD_HTTPD=OFF` excludes server-related targets; it does not make
  the remaining Windows-specific APR CMake integration a Linux build recipe.

## Source layout

```text
CMakeLists.txt           Root project, console target, shared library, module
include\
    skeleton.h          Application display name and version
    test1.h             Exported shared-library API
src\
    main.c              APR/APR-util console example
    test1.c             APR-backed response allocation
    mod_test.c          Apache request handler and module registration
cmake\                  Dependency builds, runtime templates, install helpers
external\               Third-party dependency source trees
HTTPD_TESTING.md         Additional local HTTP testing instructions
build\                  Generated outputs; ignored by Git
```
