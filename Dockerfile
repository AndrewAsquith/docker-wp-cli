FROM php:7.2-cli

# install the PHP extensions we need
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libjpeg-dev \
		libpng-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-install gd mysqli opcache; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini


VOLUME /var/www/html
VOLUME /opt
WORKDIR /var/www/html

# pub   2048R/2F6B6B7F 2016-01-07
#       Key fingerprint = 3B91 9162 5F3B 1F1B F5DD  3B47 673A 0204 2F6B 6B7F
# uid                  Daniel Bachhuber <daniel@handbuilt.co>
# sub   2048R/45F9CDE2 2016-01-07
ENV WORDPRESS_CLI_GPG_KEY 3B9191625F3B1F1BF5DD3B47673A02042F6B6B7F

ENV WORDPRESS_CLI_VERSION 1.5.1
ENV WORDPRESS_CLI_SHA512 8693cdbc06cca37be9976c4f76aa81c111095f88bb121277cbdfa85f8a2ada3b9133cd9641c439e6f5579d3469a1a44488e872ecbff3d3eba0488bbc8033d6d8

RUN set -ex; \
  \
  apt-get update; \
  apt-get install -y --no-install-recommends gnupg dirmngr curl; \
	curl -o /usr/local/bin/wp.gpg -fSL "https://github.com/wp-cli/wp-cli/releases/download/v${WORDPRESS_CLI_VERSION}/wp-cli-${WORDPRESS_CLI_VERSION}.phar.gpg"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$WORDPRESS_CLI_GPG_KEY"; \
	gpg --batch --decrypt --output /usr/local/bin/wp /usr/local/bin/wp.gpg; \
	rm -rf "$GNUPGHOME" /usr/local/bin/wp.gpg; \
	\
	echo "$WORDPRESS_CLI_SHA512 */usr/local/bin/wp" | sha512sum -c -; \
	chmod +x /usr/local/bin/wp; \
	\
	wp --allow-root --version

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
USER www-data
CMD ["wp", "shell"]
