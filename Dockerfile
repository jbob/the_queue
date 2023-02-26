FROM perl:stable
WORKDIR /app
COPY . .
RUN cpanm --notest --installdeps . && rm -r ~/.cpanm && \
    sed -i 's/localhost/mongodb/' the_queue.conf && \
    sed -i 's/\[::1\]/0.0.0.0/' the_queue.conf
CMD ["/usr/local/bin/hypnotoad", "-f", "script/the_queue"]

