#!/bin/bash

# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "$0")/version.sh"

ARCH=$(uname -m)

# improve compilation times
CORES=$(($(grep -c ^processor /proc/cpuinfo) - 1))

export MAKEFLAGS=-j${CORES}
export CTEST_BUILD_FLAGS=${MAKEFLAGS}

# Install luajit from openresty fork
export LUAJIT_LIB=/usr/local/lib
export LUA_LIB_DIR="$LUAJIT_LIB/lua"
export LUAJIT_INC=/usr/local/include/luajit-2.1

cd "$BUILD_PATH/luajit2"
make CCDEBUG=-g
make install

ln -s /usr/local/bin/luajit /usr/local/bin/lua
ln -s "$LUAJIT_INC" /usr/local/include/lua

cd "$BUILD_PATH/opentelemetry-cpp"
export CXXFLAGS="-DBENCHMARK_HAS_NO_INLINE_ASSEMBLY"
export CC="gcc"
export CXX="g++-15"
cmake -B build -G Ninja -Wno-dev \
        -DOTELCPP_PROTO_PATH="${BUILD_PATH}/opentelemetry-proto/" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_TESTING="OFF" \
        -DBUILD_W3CTRACECONTEXT_TEST="OFF" \
        -DCMAKE_BUILD_TYPE=None \
        -DWITH_ABSEIL=ON \
        -DWITH_STL=ON \
        -DCMAKE_CXX_STANDARD=23 \
        -DWITH_EXAMPLES=OFF \
        -DWITH_ZPAGES=OFF \
        -DWITH_OTLP_GRPC=ON \
        -DWITH_OTLP_HTTP=ON \
        -DWITH_ZIPKIN=ON \
        -DWITH_PROMETHEUS=OFF \
        -DWITH_ASYNC_EXPORT_PREVIEW=OFF \
        -DWITH_METRICS_EXEMPLAR_PREVIEW=OFF
      cmake --build build
      cmake --install build

# Git tuning
git config --global --add core.compression -1

# Get Brotli source and deps
cd "$BUILD_PATH"
git clone --depth=100 https://github.com/google/ngx_brotli.git
cd ngx_brotli
git reset --hard a71f9312c2deb28875acc7bacfdd5695a111aa53
git submodule init
git submodule update

cd "$BUILD_PATH"
git clone --depth=1 https://github.com/ssdeep-project/ssdeep
cd ssdeep/

./bootstrap
./configure

make
make install

# build modsecurity library
cd "$BUILD_PATH"
git clone -n https://github.com/owasp-modsecurity/ModSecurity
cd ModSecurity/
git checkout $MODSECURITY_LIB_VERSION
git submodule init
git submodule update

sh build.sh

# https://github.com/owasp-modsecurity/ModSecurity/issues/1909#issuecomment-465926762
sed -i '115i LUA_CFLAGS="${LUA_CFLAGS} -DWITH_LUA_JIT_2_1"' build/lua.m4
sed -i '117i AC_SUBST(LUA_CFLAGS)' build/lua.m4

#
# As of Alpine v3.23.0, building ModSecurity fails with:
#
# headers/modsecurity/collection/collection.h:x:x: error: 'int32_t' has not been declared
# headers/modsecurity/collection/collection.h:x:x: note: 'int32_t' is defined in header '<cstdint>'; this is probably fixable by adding '#include <cstdint>'
#
# Sadly this has not been fixed upstream, yet, so we manually patch it here.
#
sed -i '24i #include <cstdint>' headers/modsecurity/collection/collection.h

./configure \
  --disable-doxygen-doc \
  --disable-doxygen-html \
  --disable-examples

make
make install

mkdir -p /etc/nginx/modsecurity
cp modsecurity.conf-recommended /etc/nginx/modsecurity/modsecurity.conf
cp unicode.mapping /etc/nginx/modsecurity/unicode.mapping

# Replace serial logging with concurrent
sed -i 's|SecAuditLogType Serial|SecAuditLogType Concurrent|g' /etc/nginx/modsecurity/modsecurity.conf

# Concurrent logging implies the log is stored in several files
echo "SecAuditLogStorageDir /var/log/audit/" >> /etc/nginx/modsecurity/modsecurity.conf

# Download owasp modsecurity crs
cd /etc/nginx/

git clone -b $OWASP_MODSECURITY_CRS_VERSION https://github.com/coreruleset/coreruleset
mv coreruleset owasp-modsecurity-crs
cd owasp-modsecurity-crs

mv crs-setup.conf.example crs-setup.conf
mv rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
cd ..

# OWASP CRS v4 rules
echo "
Include /etc/nginx/owasp-modsecurity-crs/crs-setup.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-901-INITIALIZATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-913-SCANNER-DETECTION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-922-MULTIPART-ATTACK.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-934-APPLICATION-ATTACK-GENERIC.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-944-APPLICATION-ATTACK-JAVA.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-950-DATA-LEAKAGES.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-955-WEB-SHELLS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-980-CORRELATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
" > /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf

# build nginx
cd "$BUILD_PATH/nginx-$NGINX_VERSION"

# apply nginx patches
for PATCH in `ls /patches`;do
  echo "Patch: $PATCH"
  if [[ "$PATCH" == *.txt ]]; then
    patch -p0 < /patches/$PATCH
  else
    patch -p1 < /patches/$PATCH
  fi
done

WITH_FLAGS="--with-debug \
  --with-compat \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_realip_module \
  --with-http_auth_request_module \
  --with-http_addition_module \
  --with-http_gzip_static_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_realip_module \
  --with-stream_ssl_preread_module \
  --with-threads \
  --with-http_secure_link_module \
  --with-http_gunzip_module"

# "Combining -flto with -g is currently experimental and expected to produce unexpected results."
# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
CC_OPT="-g -O2 -fPIE -fstack-protector-strong \
  -Wformat \
  -Werror=format-security \
  -Wno-deprecated-declarations \
  -fno-strict-aliasing \
  -D_FORTIFY_SOURCE=2 \
  --param=ssp-buffer-size=4 \
  -DTCP_FASTOPEN=23 \
  -fPIC \
  -Wno-cast-function-type"

LD_OPT="-fPIE -fPIC -pie -Wl,-z,relro -Wl,-z,now"

if [[ ${ARCH} != "aarch64" ]]; then
  WITH_FLAGS+=" --with-file-aio"
fi

if [[ ${ARCH} == "x86_64" ]]; then
  CC_OPT+=' -m64 -mtune=generic'
fi

WITH_MODULES=" \
  --add-module=$BUILD_PATH/ngx_devel_kit \
  --add-module=$BUILD_PATH/set-misc-nginx-module \
  --add-module=$BUILD_PATH/headers-more-nginx-module \
  --add-module=$BUILD_PATH/lua-nginx-module \
  --add-module=$BUILD_PATH/stream-lua-nginx-module \
  --add-module=$BUILD_PATH/lua-upstream-nginx-module \
  --add-dynamic-module=$BUILD_PATH/nginx-http-auth-digest \
  --add-dynamic-module=$BUILD_PATH/ModSecurity-nginx \
  --add-dynamic-module=$BUILD_PATH/ngx_http_geoip2_module \
  --add-dynamic-module=$BUILD_PATH/ngx_brotli \
  --add-dynamic-module=$BUILD_PATH/njs/nginx"

./configure \
  --prefix=/usr/local/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --modules-path=/etc/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  ${WITH_FLAGS} \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-mail_imap_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --with-cc-opt="${CC_OPT}" \
  --with-ld-opt="${LD_OPT}" \
  --user=www-data \
  --group=www-data \
  ${WITH_MODULES}

make
make modules
make install

cd "$BUILD_PATH"

git clone https://github.com/open-telemetry/opentelemetry-cpp-contrib.git opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}

cd ${BUILD_PATH}/opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}
git reset --hard ${OPENTELEMETRY_CONTRIB_COMMIT}

export OTEL_TEMP_INSTALL=/tmp/otel
mkdir -p ${OTEL_TEMP_INSTALL}

cd ${BUILD_PATH}/opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}/instrumentation/nginx
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release \
        -G Ninja \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX=${OTEL_TEMP_INSTALL} \
        -DBUILD_SHARED_LIBS=ON \
        -DNGINX_VERSION=${NGINX_VERSION} \
        ..
cmake --build . -j ${CORES} --target install

mkdir -p /etc/nginx/modules
cp ${OTEL_TEMP_INSTALL}/otel_ngx_module.so /etc/nginx/modules/otel_ngx_module.so


cd "$BUILD_PATH/lua-resty-core"
make install

cd "$BUILD_PATH/lua-resty-balancer"
make all
make install

export LUA_INCLUDE_DIR=/usr/local/include/luajit-2.1
ln -s $LUA_INCLUDE_DIR /usr/include/lua5.1

cd "$BUILD_PATH/lua-cjson"
make all
make install

cd "$BUILD_PATH/lua-resty-cookie"
make all
make install

cd "$BUILD_PATH/lua-resty-lrucache"
make install

cd "$BUILD_PATH/lua-resty-dns"
make install

cd "$BUILD_PATH/lua-resty-lock"
make install

# required for OCSP verification
cd "$BUILD_PATH/lua-resty-http"
make install

cd "$BUILD_PATH/lua-resty-upload"
make install

cd "$BUILD_PATH/lua-resty-string"
make install

cd "$BUILD_PATH/lua-resty-memcached"
make install

cd "$BUILD_PATH/lua-resty-redis"
make install

cd "$BUILD_PATH/lua-resty-ipmatcher"
INST_LUADIR=/usr/local/lib/lua make install

cd "$BUILD_PATH/mimalloc"
mkdir -p out/release
cd out/release

# See this issue for why we disable architecture specific optimizations: https://github.com/kubernetes/ingress-nginx/issues/13608.
cmake -DMI_NO_OPT_ARCH=ON -DCMAKE_INSTALL_LIBDIR=lib ../..

make
make install

# update image permissions
writeDirs=( \
  /etc/nginx \
  /usr/local/nginx \
  /opt/modsecurity/var/log \
  /opt/modsecurity/var/upload \
  /opt/modsecurity/var/audit \
  /var/log/audit \
  /var/log/nginx \
);

groupadd -rg 101 www-data
useradd -u 101 -M -d /usr/local/nginx -s /sbin/nologin -G www-data -g www-data www-data

for dir in "${writeDirs[@]}"; do
  mkdir -p ${dir};
  chown -R www-data:www-data ${dir};
done

rm -rf /etc/nginx/owasp-modsecurity-crs/.git
rm -rf /etc/nginx/owasp-modsecurity-crs/tests

# remove .a files
find /usr/local -name "*.a" -print | xargs /bin/rm
