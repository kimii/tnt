#!/bin/sh

# check
type sc_tnt >/dev/null 2>&1 && echo -e "\033[32m[ SUCCESS sc_tnt ]\033[0m"
type sc_tnt >/dev/null 2>&1 && exit || echo -e "\033[32m[ START sc_tnt ]\033[0m"

cd /home/root/TNT
# check openssl version 1.0.2
v=$(echo $(openssl version) | cut -d' ' -f2)
if [ ${v%?} != "1.0.2" ]; then
  apt remove openssl
  wget --no-check-certificate https://www.openssl.org/source/openssl-1.0.2s.tar.gz
  tar zxvf openssl-1.0.2s.tar.gz
  rm openssl-1.0.2s.tar.gz
  cd openssl-1.0.2s/
  ./config --prefix=/usr/local --openssldir=/usr/local/openssl
  make && make install
  ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl
  ln -s /usr/local/ssl/include/openssl /usr/include/openssl
  cd ..
fi
test ${v%?} != "1.0.2" && exit
# install m4
type m4 >/dev/null 2>&1
if [ $? -ne 0 ]; then
  wget http://ftp.gnu.org/gnu/m4/m4-1.4.17.tar.gz
  tar -zxvf m4-1.4.17.tar.gz
  rm m4-1.4.17.tar.gz
  cd m4-1.4.17
  ./configure --prefix=/usr/local
  make && make install
  cd ..
fi
type m4 >/dev/null 2>&1 || exit
# install autoconf
type autoconf >/dev/null 2>&1
if [ $? -ne 0 ]; then
  wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz
  tar -zxvf autoconf-2.69.tar.gz
  rm autoconf-2.69.tar.gz
  cd ...69.tar.gz
  cd autoconf-2.69
  ./configure --prefix=/usr/local
  make && make install
  cd ..
fi
type autoconf >/dev/null 2>&1 || exit
# install automake
type automake >/dev/null 2>&1
if [ $? -ne 0 ]; then
  wget http://ftp.gnu.org/gnu/automake/automake-1.16.tar.gz
  tar -zxvf automake-1.16.tar.gz
  rm automake-1.16.tar.gz
  cd automake-1.16
  ./configure --prefix=/usr/local
  make && make install
  mkdir -p /opt

  # aclocal
  export PATH=/opt/aclocal-1.16/bin:$PATH

  cd ..
fi
type automake >/dev/null 2>&1 || exit
#  tnt dowanload
git clone https://github.com/YvesVanaubel/TNT.git

# for tnt install
cd TNT/TNT/scamper-tnt-cvs-20180523a
touch NEWS README AUTHORS ChangeLog

./configure
make
make install
type sc_tnt >/dev/null 2>&1 && echo -e "\033[32m[ SUCCESS sc_tnt ]\033[0m" || echo -e "\033[31m\033[01m[ ERROR sc_tnt ]\033[0m"


