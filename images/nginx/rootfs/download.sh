#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/version.sh"

get_src() {
  : "$1" # Checksum verification is intentionally disabled below.
  url="$2"
  dest="${3-}"
  args=""
  filename=$(basename "$url")

  echo "Downloading $url"

  curl -sSL "$url" -o "$filename"
  # TODO: Reenable checksum verification but make it smarter
  # echo "$1  $filename" | sha256sum -c - || exit 10
  if [ -n "$dest" ]; then
    mkdir "$BUILD_PATH/$dest"
    args="-C $BUILD_PATH/$dest --strip-components=1"
  fi
  tar xvzf "$filename" $args
  rm -rf "$filename"
}

# Dependencies from "ninja" and below are OpenTelemetry dependencies.
zypper install -y \
  bash gcc clang make automake libopenssl-devel pcre-devel zlib-devel \
  linux-glibc-devel libxslt-devel gd-devel libedit-devel mercurial \
  abseil-cpp-devel findutils ca-certificates patch libaio-devel openssl cmake \
  util-linux lmdb wget libcurl-devel protobuf-devel git pkgconf gcc15-c++ flex \
  bison doxygen libyajl-devel lmdb-devel libtool autoconf libxml2-2 \
  libxml2-devel python3 libmaxminddb-devel bc unzip dos2unix which \
  libyaml-cpp0_8 ninja gtest lua54-devel gzip gawk pkgconfig c-ares-devel \
  re2-devel grpc-devel

mkdir -p /etc/nginx
mkdir --verbose -p "$BUILD_PATH"
cd "$BUILD_PATH"


get_src 66dc7081488811e9f925719e34d1b4504c2801c81dee2920e5452a86b11405ae "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"

get_src aa961eafb8317e0eb8da37eb6e2c9ff42267edd18b56947384e719b85188f58b "https://github.com/vision5/ngx_devel_kit/archive/$NDK_VERSION.tar.gz" ngx_devel_kit

get_src abc123 "https://github.com/open-telemetry/opentelemetry-cpp/archive/$OPENTELEMETRY_CPP_VERSION.tar.gz" opentelemetry-cpp

get_src abc123 "https://github.com/open-telemetry/opentelemetry-proto/archive/$OPENTELEMETRY_PROTO_VERSION.tar.gz" opentelemetry-proto

get_src cd5e2cc834bcfa30149e7511f2b5a2183baf0b70dc091af717a89a64e44a2985 "https://github.com/openresty/set-misc-nginx-module/archive/$SETMISC_VERSION.tar.gz" set-misc-nginx-module

get_src 0c0d2ced2ce895b3f45eb2b230cd90508ab2a773299f153de14a43e44c1209b3 "https://github.com/openresty/headers-more-nginx-module/archive/$MORE_HEADERS_VERSION.tar.gz" headers-more-nginx-module

get_src f09851e6309560a8ff3e901548405066c83f1f6ff88aa7171e0763bd9514762b "https://github.com/atomx/nginx-http-auth-digest/archive/$NGINX_DIGEST_AUTH.tar.gz" nginx-http-auth-digest

get_src 32a42256616cc674dca24c8654397390adff15b888b77eb74e0687f023c8751b "https://github.com/owasp-modsecurity/ModSecurity-nginx/archive/$MODSECURITY_VERSION.tar.gz" ModSecurity-nginx

get_src bc764db42830aeaf74755754b900253c233ad57498debe7a441cee2c6f4b07c2 "https://github.com/openresty/lua-nginx-module/archive/$LUA_NGX_VERSION.tar.gz" lua-nginx-module

get_src 01b715754a8248cc7228e0c8f97f7488ae429d90208de0481394e35d24cef32f "https://github.com/openresty/stream-lua-nginx-module/archive/$LUA_STREAM_NGX_VERSION.tar.gz" stream-lua-nginx-module

get_src a92c9ee6682567605ece55d4eed5d1d54446ba6fba748cff0a2482aea5713d5f "https://github.com/openresty/lua-upstream-nginx-module/archive/$LUA_UPSTREAM_VERSION.tar.gz" lua-upstream-nginx-module

get_src 77bbcbb24c3c78f51560017288f3118d995fe71240aa379f5818ff6b166712ff "https://github.com/openresty/luajit2/archive/$LUAJIT_VERSION.tar.gz" luajit2

get_src b6c9c09fd43eb34a71e706ad780b2ead26549a9a9f59280fe558f5b7b980b7c6 "https://github.com/leev/ngx_http_geoip2_module/archive/$GEOIP2_VERSION.tar.gz" ngx_http_geoip2_module

get_src deb4ab1ffb9f3d962c4b4a2c4bdff692b86a209e3835ae71ebdf3b97189e40a9 "https://github.com/openresty/lua-resty-upload/archive/$LUA_RESTY_UPLOAD_VERSION.tar.gz" lua-resty-upload

get_src bdbf271003d95aa91cab0a92f24dca129e99b33f79c13ebfcdbbcbb558129491 "https://github.com/openresty/lua-resty-string/archive/$LUA_RESTY_STRING_VERSION.tar.gz" lua-resty-string

get_src 16d72ed133f0c6df376a327386c3ef4e9406cf51003a700737c3805770ade7c5 "https://github.com/openresty/lua-resty-balancer/archive/$LUA_RESTY_BALANCER.tar.gz" lua-resty-balancer

get_src 39baab9e2b31cc48cecf896cea40ef6e80559054fd8a6e440cc804a858ea84d4 "https://github.com/openresty/lua-resty-core/archive/$LUA_RESTY_CORE.tar.gz" lua-resty-core

get_src a77b9de160d81712f2f442e1de8b78a5a7ef0d08f13430ff619f79235db974d4 "https://github.com/openresty/lua-cjson/archive/$LUA_CJSON_VERSION.tar.gz" lua-cjson

get_src 5ed48c36231e2622b001308622d46a0077525ac2f751e8cc0c9905914254baa4 "https://github.com/cloudflare/lua-resty-cookie/archive/$LUA_RESTY_COOKIE_VERSION.tar.gz" lua-resty-cookie

get_src 573184006b98ccee2594b0d134fa4d05e5d2afd5141cbad315051ccf7e9b6403 "https://github.com/openresty/lua-resty-lrucache/archive/$LUA_RESTY_CACHE.tar.gz" lua-resty-lrucache

get_src b4ddcd47db347e9adf5c1e1491a6279a6ae2a3aff3155ef77ea0a65c998a69c1 "https://github.com/openresty/lua-resty-lock/archive/$LUA_RESTY_LOCK.tar.gz" lua-resty-lock

get_src 70e9a01eb32ccade0d5116a25bcffde0445b94ad35035ce06b94ccd260ad1bf0 "https://github.com/openresty/lua-resty-dns/archive/$LUA_RESTY_DNS.tar.gz" lua-resty-dns

get_src 9fcb6db95bc37b6fce77d3b3dc740d593f9d90dce0369b405eb04844d56ac43f "https://github.com/ledgetech/lua-resty-http/archive/$LUA_RESTY_HTTP.tar.gz" lua-resty-http

get_src 02733575c4aed15f6cab662378e4b071c0a4a4d07940c4ef19a7319e9be943d4 "https://github.com/openresty/lua-resty-memcached/archive/$LUA_RESTY_MEMCACHED_VERSION.tar.gz" lua-resty-memcached

get_src c15aed1a01c88a3a6387d9af67a957dff670357f5fdb4ee182beb44635eef3f1 "https://github.com/openresty/lua-resty-redis/archive/$LUA_RESTY_REDIS_VERSION.tar.gz" lua-resty-redis

get_src efb767487ea3f6031577b9b224467ddbda2ad51a41c5867a47582d4ad85d609e "https://github.com/api7/lua-resty-ipmatcher/archive/$LUA_RESTY_IPMATCHER_VERSION.tar.gz" lua-resty-ipmatcher

get_src d74f86ada2329016068bc5a243268f1f555edd620b6a7d6ce89295e7d6cf18da "https://github.com/microsoft/mimalloc/archive/${MIMALOC_VERSION}.tar.gz" mimalloc

get_src abc123 "https://github.com/nginx/njs/archive/${NJS_VERSION}.tar.gz" njs