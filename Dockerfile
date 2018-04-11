FROM alpine

RUN apk add --update --no-cache --virtual .build \
    libsasl \
    libressl2.6-libssl \
    libffi \
    yaml-dev \
    zlib-dev \
    libxslt-dev \
    libxml2-dev \
    musl-dev \
    gcc \
    bash && \
    apk add --no-cache \
    python-dev \
    py-pip \
    py-cffi \
    openldap-dev

RUN pip install --no-cache-dir realms-wiki && \
    apk del .build

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
