# syntax=docker/dockerfile:experimental
FROM php:7.4-fpm-alpine3.13 AS build
MAINTAINER nownabe

RUN apk add --update --no-cache build-base

ENV MECAB_VERSION 0.996
ENV IPADIC_VERSION 2.7.0-20070801
ENV mecab_url https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE
ENV ipadic_url https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7MWVlSDBCSXZMTXM
ENV build_deps 'curl git bash file sudo openssh'
ENV dependencies 'openssl'
ENV build_deps_phpmecab 'autoconf'

RUN apk add --update --no-cache build-base ${build_deps} ${dependencies} ${build_deps_phpmecab} \
  # Install MeCab
  && curl -SL -o mecab-${MECAB_VERSION}.tar.gz ${mecab_url} \
  && tar zxf mecab-${MECAB_VERSION}.tar.gz \
  && cd mecab-${MECAB_VERSION} \
  && ./configure --enable-utf8-only --with-charset=utf8 \
  && make \
  && make install \
  && cd \
  # Install IPA dic
  && curl -SL -o mecab-ipadic-${IPADIC_VERSION}.tar.gz ${ipadic_url} \
  && tar zxf mecab-ipadic-${IPADIC_VERSION}.tar.gz \
  && cd mecab-ipadic-${IPADIC_VERSION} \
  && ./configure --with-charset=utf8 \
  && make \
  && make install \
  && cd \
  # Install Neologd
  && git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git \
  && mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -y

# Install php-mecab
RUN git clone https://github.com/rsky/php-mecab.git \
  && cd ./php-mecab/mecab \
  && phpize \
  && ./configure --with-php-config=/usr/local/bin/php-config --with-mecab=/usr/local/bin/mecab-config \
  && make \
  && make test \
  && make install

FROM alpine:3.13 as app

COPY --from=build /usr/local/lib/libmecab.so.2* /usr/local/lib
COPY --from=build /usr/local/lib/mecab /usr/local/lib/mecab
COPY --from=build /usr/local/libexec/mecab/ /usr/local/libexec/mecab
COPY --from=build ["/usr/local/bin/mecab", "/usr/local/bin/mecab-config", "/usr/local/bin/"]
COPY --from=build /var/www/html/php-mecab/mecab/modules/mecab.so /var/www/html/php-mecab/mecab/modules/mecab.so
COPY --from=build /var/www/html/mecab-0.996/mecabrc /var/www/html/mecab-0.996/mecabrc
COPY --from=build /root/mecab-ipadic-neologd/ /root/mecab-ipadic-neologd/
COPY config/mecab.ini /root/mecab.ini

USER nobody