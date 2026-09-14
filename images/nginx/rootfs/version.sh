#!/bin/bash

# Check for recent changes: https://nginx.org/en/download.html
export NGINX_VERSION=1.27.1

# Check for recent changes: https://github.com/vision5/ngx_devel_kit/compare/v0.3.3...master
export NDK_VERSION=v0.3.3
# Check for recent changes: https://github.com/openresty/set-misc-nginx-module/compare/v0.33...master
export SETMISC_VERSION=v0.33
# Check for recent changes: https://github.com/openresty/headers-more-nginx-module/compare/v0.37...master
export MORE_HEADERS_VERSION=v0.37
# Check for recent changes: https://github.com/atomx/nginx-http-auth-digest/compare/v1.0.0...master
export NGINX_DIGEST_AUTH=v1.0.0
# Check for recent changes: https://github.com/owasp-modsecurity/ModSecurity-nginx/compare/v1.0.4...master
export MODSECURITY_VERSION=v1.0.4
# Check for recent changes: https://github.com/owasp-modsecurity/ModSecurity/compare/v3.0.14...v3/master
export MODSECURITY_LIB_VERSION=v3.0.14
# Check for recent changes: https://github.com/coreruleset/coreruleset/compare/v4.22.0...main
export OWASP_MODSECURITY_CRS_VERSION=v4.22.0
# Check for recent changes: https://github.com/openresty/lua-nginx-module/compare/v0.10.28...master
export LUA_NGX_VERSION=v0.10.28
# Check for recent changes: https://github.com/openresty/stream-lua-nginx-module/compare/v0.0.16...master
export LUA_STREAM_NGX_VERSION=v0.0.16
# Check for recent changes: https://github.com/openresty/lua-upstream-nginx-module/compare/v0.07...master
export LUA_UPSTREAM_VERSION=v0.07
# Check for recent changes: https://github.com/openresty/lua-cjson/compare/2.1.0.14...master
export LUA_CJSON_VERSION=2.1.0.14
# Check for recent changes: https://github.com/leev/ngx_http_geoip2_module/compare/445df24ef3781e488cee3dfe8a1e111997fc1dfe...master
export GEOIP2_VERSION=445df24ef3781e488cee3dfe8a1e111997fc1dfe
# Check for recent changes: https://github.com/openresty/luajit2/compare/v2.1-20250117...v2.1-agentzh
export LUAJIT_VERSION=v2.1-20250117
# Check for recent changes: https://github.com/openresty/lua-resty-balancer/compare/v0.05...master
export LUA_RESTY_BALANCER=v0.05
# Check for recent changes: https://github.com/openresty/lua-resty-lrucache/compare/v0.15...master
export LUA_RESTY_CACHE=v0.15
# Check for recent changes: https://github.com/openresty/lua-resty-core/compare/v0.1.31...master
export LUA_RESTY_CORE=v0.1.31
# Check for recent changes: https://github.com/cloudflare/lua-resty-cookie/compare/f418d77082eaef48331302e84330488fdc810ef4...master
export LUA_RESTY_COOKIE_VERSION=f418d77082eaef48331302e84330488fdc810ef4
# Check for recent changes: https://github.com/openresty/lua-resty-dns/compare/v0.23...master
export LUA_RESTY_DNS=v0.23
# Check for recent changes: https://github.com/ledgetech/lua-resty-http/compare/v0.17.2...master
export LUA_RESTY_HTTP=v0.17.2
# Check for recent changes: https://github.com/openresty/lua-resty-lock/compare/v0.09...master
export LUA_RESTY_LOCK=v0.09
# Check for recent changes: https://github.com/openresty/lua-resty-upload/compare/v0.11...master
export LUA_RESTY_UPLOAD_VERSION=v0.11
# Check for recent changes: https://github.com/openresty/lua-resty-string/compare/v0.16...master
export LUA_RESTY_STRING_VERSION=v0.16
# Check for recent changes: https://github.com/openresty/lua-resty-memcached/compare/v0.17...master
export LUA_RESTY_MEMCACHED_VERSION=v0.17
# Check for recent changes: https://github.com/openresty/lua-resty-redis/compare/v0.31...master
export LUA_RESTY_REDIS_VERSION=v0.31
# Check for recent changes: https://github.com/api7/lua-resty-ipmatcher/compare/3e93c53eb8c9884efe939ef070486a0e507cc5be...master
export LUA_RESTY_IPMATCHER_VERSION=3e93c53eb8c9884efe939ef070486a0e507cc5be
# Check for recent changes: https://github.com/microsoft/mimalloc/compare/v2.2.4...main
export MIMALOC_VERSION=v2.2.4
# Check for recent changes: https://github.com/open-telemetry/opentelemetry-cpp/compare/v1.19.0...main
export OPENTELEMETRY_CPP_VERSION=v1.19.0
# Check for recent changes: https://github.com/open-telemetry/opentelemetry-proto/compare/v1.5.0...main
export OPENTELEMETRY_PROTO_VERSION=v1.5.0
# Check for recent changes: https://github.com/nginx/njs/compare/0.9.0...master
export NJS_VERSION=0.9.0
# Check for recent changes: https://github.com/open-telemetry/opentelemetry-cpp-contrib/compare/8933841f0a7f8737f61404cf0a64acf6b079c8a5...main
export OPENTELEMETRY_CONTRIB_COMMIT=8933841f0a7f8737f61404cf0a64acf6b079c8a5

export BUILD_PATH=/tmp/build