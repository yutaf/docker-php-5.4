FROM ubuntu:14.04.3
MAINTAINER yutaf <yutafuji2008@gmail.com>

RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
# binary
    curl \
    git \
    mysql-client \
# Apache, php \
    make \
    gcc \
    zlib1g-dev \
    libssl-dev \
    libpcre3-dev \
# php
    perl \
    libxml2-dev \
    libjpeg-dev \
    libpng12-dev \
    libfreetype6-dev \
    libmcrypt-dev \
    libcurl4-openssl-dev \
    libreadline-dev \
    libicu-dev \
    g++ \
# xdebug
    autoconf \
# ffmpeg
    automake \
    build-essential \
    libtool \
    libx264-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    yasm \
# supervisor
    supervisor && \
  rm -r /var/lib/apt/lists/*

#
# Apache
#
RUN \
  mkdir -p /usr/local/src/apache && \
  cd /usr/local/src/apache && \
  curl -L -O http://archive.apache.org/dist/httpd/httpd-2.2.27.tar.gz && \
  tar xzvf httpd-2.2.27.tar.gz && \
  cd httpd-2.2.27 && \
    ./configure \
      --prefix=/opt/apache2.2.27 \
      --enable-mods-shared=all \
      --enable-proxy \
      --enable-ssl \
      --with-ssl \
      --with-mpm=prefork \
      --with-pcre && \
  make && \
  make install && \
  rm -r /usr/local/src/apache

#
# php
#
RUN \
  mkdir -p /usr/local/src/php && \
  cd /usr/local/src/php && \
  curl -L -O http://php.net/distributions/php-5.4.35.tar.gz && \
  tar xzvf php-5.4.35.tar.gz && \
  cd php-5.4.35 && \
  ./configure \
    --prefix=/opt/php-5.4.35 \
    --with-config-file-path=/srv/php \
    --with-apxs2=/opt/apache2.2.27/bin/apxs \
    --with-libdir=lib64 \
    --enable-mbstring \
    --enable-intl \
    --with-icu-dir=/usr \
    --with-gettext=/usr \
    --with-pcre-regex=/usr \
    --with-pcre-dir=/usr \
    --with-readline=/usr \
    --with-libxml-dir=/usr/bin/xml2-config \
    --with-mysql=mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-zlib=/usr \
    --with-zlib-dir=/usr \
    --with-gd \
    --with-jpeg-dir=/usr \
    --with-png-dir=/usr \
    --with-freetype-dir=/usr \
    --enable-gd-native-ttf \
    --enable-gd-jis-conv \
    --with-openssl=/usr \
# ubuntu only
    --with-libdir=/lib/x86_64-linux-gnu \
    --with-mcrypt=/usr \
    --enable-bcmath \
    --with-curl \
    --enable-zip \
    --enable-exif && \
  make && \
  make install && \
  rm -r /usr/local/src/php

# workaround for curl certification error
COPY templates/ca-bundle-curl.crt /root/ca-bundle-curl.crt
#RUN curl -k -L -o $HOME/ca-bundle-curl.crt https://curl.haxx.se/ca/cacert.pem

# Add php to PATHs to compile extensions like xdebug
ENV PATH /opt/php-5.4.35/bin:$PATH

# xdebug
RUN \
  mkdir -p /usr/local/src/xdebug && \
  cd /usr/local/src/xdebug && \
  curl --cacert $HOME/ca-bundle-curl.crt -L -O http://xdebug.org/files/xdebug-2.3.3.tgz && \
  tar -xzf xdebug-2.3.3.tgz && \
  cd xdebug-2.3.3 && \
  phpize && \
  ./configure --enable-xdebug && \
  make && \
  make install && \
  cd && \
  rm -r /usr/local/src/xdebug

# redis
RUN \
  pecl install redis-2.2.8


# php.ini
COPY templates/php.ini /srv/php/
RUN echo 'zend_extension = "/opt/php-5.4.35/lib/php/extensions/no-debug-non-zts-20100525/xdebug.so"' >> /srv/php/php.ini

#
# ffmpeg
#

# fdk-aac
RUN \
  git clone --depth 1 git://git.code.sf.net/p/opencore-amr/fdk-aac && \
  cd fdk-aac && \
  autoreconf -fiv && \
  ./configure --prefix="/usr/local/ffmpeg_build" --disable-shared && \
  make && \
  make install && \
  cd ../ && \
  rm -rf fdk-aac && \
# ffmpeg
  git clone --depth 1 git://source.ffmpeg.org/ffmpeg && \
  cd ffmpeg && \
  PKG_CONFIG_PATH="/usr/local/ffmpeg_build/lib/pkgconfig/" ./configure \
    --prefix="/usr/local/ffmpeg_build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I/usr/local/ffmpeg_build/include" \
    --extra-ldflags="-L/usr/local/ffmpeg_build/lib" \
    --bindir="/usr/local/bin" \
    --extra-libs=-ldl \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk_aac \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libx264 && \
  make && \
  make install && \
  cd .. && \
  rm -rf ffmpeg && \
# Delete build sources
  rm -rf /usr/local/ffmpeg_build

#
# Edit config files
#

# Apache config
RUN sed -i "s/^Listen 80/#&/" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s/^DocumentRoot/#&/" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "/^<Directory/,/^<\/Directory/s/^/#/" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s;ScriptAlias /cgi-bin;#&;" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s;#\(Include conf/extra/httpd-mpm.conf\);\1;" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s;#\(Include conf/extra/httpd-default.conf\);\1;" /opt/apache2.2.27/conf/httpd.conf && \
# DirectoryIndex; index.html precedes index.php
  sed -i "/^\s*DirectoryIndex/s/$/ index.php/" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s/\(ServerTokens \)Full/\1Prod/" /opt/apache2.2.27/conf/extra/httpd-default.conf && \
  echo "Include /srv/apache/apache.conf" >> /opt/apache2.2.27/conf/httpd.conf && \
# Change User & Group
  useradd --system --shell /usr/sbin/nologin --user-group --home /dev/null apache; \
  sed -i "s;^\(User \)daemon$;\1apache;" /opt/apache2.2.27/conf/httpd.conf && \
  sed -i "s;^\(Group \)daemon$;\1apache;" /opt/apache2.2.27/conf/httpd.conf

COPY templates/apache.conf /srv/apache/apache.conf
RUN echo 'CustomLog "|/opt/apache2.2.27/bin/rotatelogs /srv/www/logs/access/access.%Y%m%d.log 86400 540" combined' >> /srv/apache/apache.conf && \
  echo 'ErrorLog "|/opt/apache2.2.27/bin/rotatelogs /srv/www/logs/error/error.%Y%m%d.log 86400 540"' >> /srv/apache/apache.conf && \
  mkdir -p /srv/www/logs && \
  cd /srv/www/logs && \
  mkdir -m 777 access error app && \
  cd - && \
# make Apache document root directory
  mkdir -p /srv/www/htdocs/ && \
  echo "<?php echo 'hello, php';" > /srv/www/htdocs/index.php && \
  echo "<?php phpinfo();" > /srv/www/htdocs/info.php

# supervisor
COPY templates/supervisord.conf /etc/supervisor/conf.d/
RUN \
  echo '[program:apache2]' >> /etc/supervisor/conf.d/supervisord.conf && \
  echo 'command=/opt/apache2.2.27/bin/httpd -DFOREGROUND' >> /etc/supervisor/conf.d/supervisord.conf && \
# set PATH
  sed -i 's;^PATH="[^"]*;&:/opt/php-5.4.35/bin;' /etc/environment && \
# set TERM
  echo export TERM=xterm-256color >> /root/.bashrc && \
# set timezone
#  ln -sf /usr/share/zoneinfo/Japan /etc/localtime && \
# Delete logs except dot files
  echo '00 5 1,15 * * find /srv/www/logs -not -regex ".*/\.[^/]*$" -type f -mtime +15 -exec rm -f {} \;' > /root/crontab && \
  crontab /root/crontab

# Set up script for running container
COPY scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

WORKDIR /srv/www
EXPOSE 80
CMD ["/usr/local/bin/run.sh"]
