ARG SBCL_VERSION=2.0.9
FROM fukamachi/sbcl:${SBCL_VERSION}
ARG QLOT_VERSION=0.10.6
ENV LANG C.UTF-8
ENV GH_HOOKS_DIR /app/hooks

RUN ros install fukamachi/qlot/${QLOT_VERSION}

WORKDIR /app
COPY . /app
RUN cat /app/docker/init.lisp >> ~/.roswell/init.lisp

RUN qlot install && \
  qlot exec ros -e "(ql:quickload :github-webhook)"

EXPOSE 5000
ENTRYPOINT ["/app/docker/entrypoint.sh"]
