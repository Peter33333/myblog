FROM jekyll/jekyll:4.2.0

WORKDIR /srv/jekyll

# ENV http_proxy host.docker.internal:8889
# ENV https_proxy host.docker.internal:8889

COPY . .
# RUN chown -R jekyll:jekyll /srv/jekyll
# RUN gem install bundler -v 2.4.22
# RUN bundle update
RUN bundle install

USER root

CMD ["jekyll", "serve", "--trace"]
# docker build -t my-jekyll-site .
# docker run -d -p 4000:4000 my-jekyll-site