# Local HTTPS testing with Apache on Windows

This guide creates a **local test CA** and a server certificate, then runs the
project's Apache with OpenSSL and `mod_ssl`. The HTTPS configuration listens
only on `127.0.0.1:8443`. It is not a production configuration, and the test CA
is not publicly trusted. Do not expose it or reuse these keys for real sites.

## 1. Obtain sources and build

Follow the dependency checkout instructions in [README.md](README.md), including
the caveat about dependencies without tracked gitlinks. Install Visual Studio's
C++ build tools, CMake 3.20 or newer, Git, and native Windows Perl. In PowerShell
from the repository root:

```powershell
cmake -S . -B build "-DOPENSSL_PERL_EXECUTABLE=C:\path\to\perl.exe"
cmake --build build --config Debug --target mod_test --parallel 4
```

Replace the Perl path with your native Windows Perl executable, or omit the
option if it is already found on `PATH`. `SKELETON_BUILD_OPENSSL` and
`SKELETON_BUILD_HTTPD` must be enabled (the defaults). Building `mod_test`
builds the OpenSSL libraries, httpd with `mod_ssl`, and the custom DLL and
module. Use the same configuration throughout; for Release, replace `Debug`
in the commands and paths.

The project's OpenSSL build installs libraries, not the `openssl.exe` command.
Install a separate trusted native Windows OpenSSL command-line distribution
and make `openssl.exe` available on `PATH`. The following certificate commands
use that tool, not the project's staged libraries. Use OpenSSL 3.0 or newer;
check it with `openssl version`. Stop if any command fails.

## 2. Create a test CA and issue a server certificate

From the project root, choose the staged server and create directories:

```powershell
$server = (Resolve-Path .\build\httpd\Debug).Path
$httpd = Join-Path $server 'bin\httpd.exe'
$ca = Join-Path (Resolve-Path .\build).Path 'local-test-ca'
$ssl = Join-Path $server 'conf\ssl'
New-Item -ItemType Directory -Force $ca, $ssl | Out-Null
$requestConfig = Join-Path $ca 'request.cnf'
@'
[req]
distinguished_name=dn
[dn]
'@ | Set-Content -Encoding ascii $requestConfig
```

The minimal request configuration avoids relying on the OpenSSL command's
installation-specific default `openssl.cnf`.

The commands below generate new private keys and overwrite files with the same
names. Do not run them over existing credentials you need to keep. Restrict
access to these directories and files using Windows file permissions. Keep
`ca.key` secret and outside the server directory; anyone holding it can issue
certificates trusted by clients that trust this CA. Never commit private keys.

Create a self-signed CA valid for one year:

```powershell
openssl req -config "$requestConfig" -x509 -newkey rsa:3072 -noenc -sha256 -days 365 `
  -keyout "$ca\ca.key" -out "$ca\ca.crt" -subj "/CN=Skeleton Local Test CA" `
  -addext "basicConstraints=critical,CA:TRUE" `
  -addext "keyUsage=critical,keyCertSign,cRLSign"
```

Create a server key and certificate signing request (CSR). The key is
unencrypted because Apache must start unattended; protect it with filesystem
permissions.

```powershell
openssl req -config "$requestConfig" -new -newkey rsa:2048 -noenc -sha256 `
  -keyout "$ssl\server.key" -out "$ssl\server.csr" -subj "/CN=localhost"
@'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
'@ | Set-Content -Encoding ascii "$ssl\server.ext"
openssl x509 -req -in "$ssl\server.csr" -CA "$ca\ca.crt" -CAkey "$ca\ca.key" `
  -CAcreateserial -out "$ssl\server.crt" -days 90 -sha256 -extfile "$ssl\server.ext"
openssl verify -CAfile "$ca\ca.crt" -verify_ip 127.0.0.1 "$ssl\server.crt"
openssl x509 -in "$ssl\server.crt" -noout -dates -ext subjectAltName
```

The certificate's subject alternative names authorize both `localhost` and
`127.0.0.1`; other hostnames and IP addresses fail hostname verification. The
server reads `conf\ssl\server.crt` and `conf\ssl\server.key`. The CA private
key and serial file remain outside the server directory. Renew before expiry
by issuing a new certificate, then restart Apache; rotate compromised keys and
replace the CA if its key is compromised. Remove the test CA and keys when no
longer needed.

## 3. Configure and start Apache

The build renders `cmake\httpd-test-ssl.conf.in` as
`build\httpd\Debug\conf\test-httpd-ssl.conf`. It loads `mod_ssl`, the shared
session cache module, `test1.dll`, and `mod_test.so`. The HTTP and HTTPS
templates have distinct ports, PID files, and logs. Verify the syntax and
loaded modules, then start HTTPS in the foreground:

```powershell
& $httpd -f "$server\conf\test-httpd-ssl.conf" -t
& $httpd -f "$server\conf\test-httpd-ssl.conf" -M
& $httpd -f "$server\conf\test-httpd-ssl.conf"
```

Stop with **Ctrl+C**. If the port is occupied, change `Listen` and `ServerName`
in the template and regenerate with
`cmake "-DHTTPD_TEST_ROOT:PATH=$server" -P .\cmake\PrepareHttpdTest.cmake`,
then use the new port in client URLs. Do not stop unrelated processes.

## 4. Connect over HTTPS

In another PowerShell terminal from the project root:

```powershell
$ca = Join-Path (Resolve-Path .\build).Path 'local-test-ca'
curl.exe --fail --show-error --ssl-no-revoke --cacert "$ca\ca.crt" https://127.0.0.1:8443/
curl.exe --fail --show-error --ssl-no-revoke --cacert "$ca\ca.crt" https://127.0.0.1:8443/test
curl.exe --head --ssl-no-revoke --cacert "$ca\ca.crt" https://127.0.0.1:8443/test
```

The first request serves the sample page; `/test` returns
`libtest1 is running.`. `--cacert` trusts this CA for that invocation while
retaining certificate and hostname verification. Without that trust, clients
should reject the certificate. Windows curl's Schannel backend checks
revocation by default, but this test CA does not publish revocation
information. `--ssl-no-revoke` disables only that check for this local test;
do not use it as a production revocation strategy. Avoid `-k` / `--insecure`:
it disables the verification this exercise is intended to test. Browsers will not trust the CA
by default; use a test client with explicit CA trust rather than installing a
test root globally. If you choose to trust it in a browser or OS store, use a
dedicated test environment and remove it afterward.

## Troubleshooting

- Check `build\httpd\Debug\logs\test-https-error.log`, Apache's `-t` output,
  certificate paths, and private-key permissions.
- Missing `mod_ssl.so` means OpenSSL was disabled or the HTTPS build failed;
  configure with `SKELETON_BUILD_OPENSSL=ON` and rebuild `mod_test`.
- Certificate verification errors can mean a wrong CA, expired certificate, or
  an address absent from the certificate's subject alternative names.
- Stop the server before rebuilding its loaded modules: Windows locks DLLs.
  Keep the server, modules, and OpenSSL build configuration consistent.
- This configuration enables TLS 1.2 and 1.3, not HTTP/2. Public deployments
  require a trusted certificate, appropriate security configuration, and
  operational controls beyond this local example.
