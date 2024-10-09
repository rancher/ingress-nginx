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
# With BCI as base image, with the SLES 15 SP6 tag, which has a newer version of glibc
FROM registry.suse.com/bci/bci-base:15.6 as builder
 
RUN zypper addrepo -p 105 http://download.opensuse.org/distribution/leap/15.6/repo/oss/ download.opensuse.org-oss && \
    zypper --gpg-auto-import-keys refresh

COPY patches /patches
COPY --chmod=0755 build.sh /

RUN /build.sh

# Use a multi-stage build
FROM registry.suse.com/bci/bci-base:15.6

ENV PATH=$PATH:/usr/local/luajit/bin:/usr/local/nginx/sbin:/usr/local/nginx/bin

ENV LUA_PATH="/usr/local/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/lib/lua/?.lua;;"
ENV LUA_CPATH="/usr/local/lib/lua/?/?.so;/usr/local/lib/lua/?.so;;"

COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib64/libopentelemetry* /usr/lib64/
COPY --from=builder /opt /opt
COPY --from=builder /etc/nginx /etc/nginx

RUN ln -s /usr/lib64/liblua5.3.so.5.3.0 /usr/local/lib/liblua-5.3.so

RUN zypper addrepo \
    -p 105 http://download.opensuse.org/distribution/leap/15.6/repo/oss/ download.opensuse.org-oss && \
    zypper --gpg-auto-import-keys refresh
RUN zypper install -y --allow-vendor-change \
    liblmdb-0_9_30 \
    libxml2-tools \
    libmaxminddb0 \
    libcap-progs \    
    crypto-policies-scripts \
    libgrpc++1 \
    libatomic1 \
    grpc-devel \
    wget \
    which \
    git \
    libyajl2 \
    openssl-3 \
    libicu73_2 \
    liblua5_4-5 \
    make \
    tar \
    gzip \
    catatonit

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
