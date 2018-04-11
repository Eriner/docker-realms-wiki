FROM alpine AS base
WORKDIR /app

FROM base AS dependencies
RUN apk add --update --no-cache \
    libsasl \
    libressl2.6-libssl \
    libffi-dev \
    yaml-dev \
    zlib-dev \
    libxslt-dev \
    libxml2-dev \
    musl-dev \
    gcc \
    python-dev \
    py-pip \
    py-cffi \
    openldap-dev \
    zip \
    unzip \
    nodejs-npm

FROM dependencies AS build
RUN pip install --no-cache-dir wheel && \
    pip wheel --wheel-dir=/app/wheels realms-wiki && \
    npm install -g uglify-js && \
    cd wheels && \
    pkg=realms_wiki*.whl && pkg=$(echo ${pkg}) && \
    echo ${pkg} && \
    mkdir minify && cd minify && mv ../${pkg} . && \
    unzip ${pkg} 2>/dev/null && rm ${pkg} && \
    pwd && \
    ls -lah . && \
    echo 'minifying js. Be patient, this will take a while...' && \
    find -name '*.js' -type f -exec sh -c 'uglifyjs {} -o {}; echo minifying: {};' \; 2>/dev/null && \
    zip -r ../${pkg} . 2>/dev/null && cd .. && rm -rf minify


FROM alpine as release
WORKDIR /app
COPY --from=build /app/ ./
#NOTE: yaml-dev may be needed for reading config files; this wasn't tested.
RUN apk add --update --no-cache \
    python \
    py-setuptools \
    py-pip \
    py-cffi \
    openldap-dev && \
    pip install --use-wheel --no-index --find-links=/app/wheels realms-wiki && \
    apk del py-pip && \
    rm -rf /app/wheels

RUN addgroup \
    -S -g 1000 \
    wiki && \
  adduser \
    -S -H -D \
    -h /data \
    -s /bin/bash \
    -u 1000 \
    -G wiki \

USER wiki

ENV WORKERS=3 \
    GEVENT_RESOLVER=ares \
    REALMS_ENV=docker \
    REALMS_WIKI_PATH=/data/wiki/repo \
    REALMS_DB_URI='sqlite:////data/db/wiki.db'

VOLUME /data/config
VOLUME /data/db
VOLUME /data/wiki

EXPOSE 5000

WORKDIR /data/config

CMD gunicorn \
--name realms-wiki \
--access-logfile - \
--error-logfile - \
--worker-class gevent \
--workers ${WORKERS} \
--bind 0.0.0.0:5000 \
'realms:create_app()'
