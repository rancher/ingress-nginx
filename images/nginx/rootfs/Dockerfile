# Copyright 2024 The Kubernetes Authors. All rights reserved.
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
# BCI 16.0 provides the newer glibc required by the compiled nginx modules.
ARG BCI_BUILD_IMAGE=registry.suse.com/bci/bci-base:16.0
ARG BCI_RUNTIME_IMAGE=registry.suse.com/bci/bci-minimal:16.0

FROM ${BCI_BUILD_IMAGE} AS builder
 
RUN zypper addrepo -p 105 http://download.opensuse.org/distribution/leap/16.0/repo/oss/ download.opensuse.org-oss && \
    zypper --gpg-auto-import-keys refresh

COPY --chmod=0755 version.sh download.sh /

RUN /download.sh

COPY patches /patches
COPY --chmod=0755 build.sh /

RUN /build.sh

# Populate a BCI Minimal root filesystem through Zypper without including the
# package manager or its metadata in the published image.
FROM ${BCI_RUNTIME_IMAGE} AS runtime_rootfs

FROM builder AS runtime_packages

COPY --from=runtime_rootfs / /rootfs
COPY --from=builder /etc/zypp/repos.d/ /rootfs/etc/zypp/repos.d/
COPY packages.txt /tmp/packages.txt

RUN zypper --root /rootfs --gpg-auto-import-keys refresh && \
  zypper --root /rootfs --gpg-auto-import-keys install -y --allow-vendor-change $(sed 's/#.*//' /tmp/packages.txt) && \
  rm -rf /rootfs/etc/zypp /rootfs/var/cache/zypp

FROM runtime_rootfs

COPY --from=runtime_packages /rootfs/ /

ENV PATH=$PATH:/usr/local/luajit/bin:/usr/local/nginx/sbin:/usr/local/nginx/bin

ENV LUA_PATH="/usr/local/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/lib/lua/?.lua;;"
ENV LUA_CPATH="/usr/local/lib/lua/?/?.so;/usr/local/lib/lua/?.so;;"

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib64/libopentelemetry* /usr/lib64/
COPY --from=builder /usr/lib64/libbrotli* /usr/lib64/
COPY --from=builder /opt /opt
COPY --from=builder /etc/nginx /etc/nginx

RUN ln -s /usr/lib64/liblua5.3.so.5.3.0 /usr/local/lib/liblua-5.3.so

RUN ldDirs=" \
      /usr/local/lib \
      /usr/local/lib64 \
  "; \
  for dir in ${ldDirs}; do \
    echo "${dir}" >>/etc/ld.so.conf.d/local.conf; \
  done
RUN /sbin/ldconfig

RUN ln -s /usr/local/nginx/sbin/nginx /sbin/nginx
RUN groupadd -rg 101 www-data && \
    useradd -u 101 -M -d /usr/local/nginx -s /sbin/nologin -G www-data -g www-data www-data

RUN writeDirs=" \
      /var/log/nginx \
      /var/lib/nginx/body \
      /var/lib/nginx/fastcgi \
      /var/lib/nginx/proxy \
      /var/lib/nginx/scgi \
      /var/lib/nginx/uwsgi \
      /var/log/audit \
  "; \
  for dir in ${writeDirs}; do \
    mkdir -p ${dir}; \
    chown -R www-data.www-data ${dir}; \
  done

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
