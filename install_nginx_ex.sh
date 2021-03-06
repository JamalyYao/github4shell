#!/bin/bash

yum_server='yum.server.local'
yum_pkg='gcc gcc-c++ openssl openssl-devel glib2-devel pcre-devel bzip2-devel'

#SET TEMP DIR
tmp_dir="/tmp/install_$$"

#ex pkg dir
src_dir='/usr/local/src'

#SET EXIT STATUS AND COMMAND
trap "exit 1"           HUP INT PIPE QUIT TERM
trap "test -d ${tmp_dir} && rm -rf ${tmp_dir}"  EXIT

ls /usr/bin/yum >/dev/null 2>&1 ||\
eval "echo 未安装yum!;exit 1"

yum --skip-broken --nogpgcheck install -y ${yum_pkg} > /tmp/yum.log 2>&1 ||\
eval "echo yum安装失败!日志请查看: /tmp/yum.log ;exit 1"

download_pkg () {
local pkg="$1"
local url="http://${yum_server}/tools/${pkg}"
test -d ${tmp_dir} || mkdir -p ${tmp_dir}
wget -q ${url} -O ${tmp_dir}/${pkg} ||\
eval "echo wget ${url} 下载失败;exit 1"
}

decompress_pkg () {
local pkg="$1"
test -d ${tmp_dir} && cd ${tmp_dir}
test -f ${pkg} && tar xzf ${pkg} ||\
eval "echo ${pkg}不存在;exit 1"
}

pkg_path () {
local pkg="$1"
local pkg_dir=`echo ${pkg}|sed 's/\.tar\.gz//'`
echo "${tmp_dir}/${pkg_dir}"
}

cd_to_path () {
local pkg_path="$1"
test -d ${pkg_path} && cd ${pkg_path} || \
eval "echo 未找到${pkg_path};exit 1"
}

#install LuaJIT
pkg='LuaJIT-2.0.4.tar.gz'
download_pkg "${pkg}"
decompress_pkg "${pkg}"
pkg_path=`pkg_path "${pkg}"`
cd_to_path "${pkg_path}"

make > /tmp/install_${pkg}.log 2>&1 &&\
make install > /tmp/install_${pkg}.log 2>&1 ||\
eval "echo ${pkg} 编译失败!请查看日志: /tmp/install_${pkg}.log;exit 1"

test -f /usr/local/lib/libluajit-5.1.so.2 &&\
ln -s /usr/local/lib/libluajit-5.1.so.2 /lib64/libluajit-5.1.so.2||\
eval "echo /usr/local/lib/libluajit-5.1.so.2 not found!;exit 1"

test -f /etc/profile.d/luajit.sh ||\
echo 'export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.0' > /etc/profile.d/luajit.sh

#download lua-nginx-module-0.9.16.tar.gz
pkg='lua-nginx-module-0.9.16.tar.gz'
download_pkg "${pkg}"
decompress_pkg "${pkg}"
pkg_path=`pkg_path "${pkg}"`
test -d "${pkg_path}" &&\
mv ${pkg_path} ${src_dir}/
pkg_dir=`echo ${pkg}|sed 's/\.tar\.gz//'`
lua_nginx_module_path="${src_dir}/${pkg_dir}"

#download nginx-goodies-nginx-sticky-module-ng.tar.gz
pkg='nginx-goodies-nginx-sticky-module-ng.tar.gz'
download_pkg "${pkg}"
decompress_pkg "${pkg}"
pkg_path=`pkg_path "${pkg}"`
test -d "${pkg_path}" &&\
mv ${pkg_path} ${src_dir}/
pkg_dir=`echo ${pkg}|sed 's/\.tar\.gz//'`
nginx_sticky_module_path="${src_dir}/${pkg_dir}"

#download ngx_devel_kit-0.2.19.tar.gz
pkg='ngx_devel_kit-0.2.19.tar.gz'
download_pkg "${pkg}"
decompress_pkg "${pkg}"
pkg_path=`pkg_path "${pkg}"`
test -d "${pkg_path}" &&\
mv ${pkg_path} ${src_dir}/
pkg_dir=`echo ${pkg}|sed 's/\.tar\.gz//'`
ngx_devel_kit_path="${src_dir}/${pkg_dir}"

#install nginx
pkg='nginx-1.6.3.tar.gz'
download_pkg "${pkg}"
decompress_pkg "${pkg}"
pkg_path=`pkg_path "${pkg}"`
cd_to_path "${pkg_path}"

test -f /etc/profile.d/luajit.sh &&\
source /etc/profile.d/luajit.sh ||\
eval "echo /etc/profile.d/luajit.sh not found!;exit 1"

path2install='/usr/local/nginx'
 
./configure --prefix=${path2install} --with-http_stub_status_module --with-http_ssl_module \
--add-module=${lua_nginx_module_path} \
--add-module=${nginx_sticky_module_path} \
--add-module=${ngx_devel_kit_path} > /tmp/install_${pkg}.log 2>&1 ||\
eval "echo 编译nginx失败!日志请查看: /tmp/install_${pkg}.log ;exit 1"

make -j 4 >> /tmp/install_${pkg}.log 2>&1 ||\
eval "echo 编译nginx失败!日志请查看: /tmp/install_${pkg}.log ;exit 1"

make install >> /tmp/install_${pkg}.log 2>&1 ||\
eval "echo 编译nginx失败!日志请查看: /tmp/install_${pkg}.log ;exit 1"

test -d /etc/ld.so.conf.d &&\
echo '/usr/local/lib' > /etc/ld.so.conf.d/ex_module.conf

useradd -s /sbin/nologin nginx
ln -sf /usr/local/nginx/sbin/nginx  /usr/sbin

test -d ${path2install} && chown nginx.nginx -R ${path2install}

nginx -t && nginx -V 
