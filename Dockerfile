FROM debian:stretch
MAINTAINER tuyoshia
# Get noninteractive frontend for Debian to avoid some problems:
#    debconf: unable to initialize frontend: Dialog
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre
RUN apt-get -y install ruby ruby-dev
RUN apt-get -y install imagemagick libicu-dev zlib1g-dev unzip
RUN apt-get -y install openjdk-8-jre-headless git libxslt1-dev build-essential nodejs redis-server
RUN apt-get -y install postgresql libpq-dev
RUN gem install rails -v=5.1.6
RUN gem install foreman whenever
# RUN rm -rf /var/lib/apt/lists/* 

# install enju
RUN rails _5.1.6_ new my_enju -d postgresql --skip-bundle --skip-turbolinks \
    -m https://gist.github.com/nabeta/6c56f0edf5cc1c80d9c655c2660a9c59.txt
WORKDIR /my_enju
RUN bundle -j4 --path vendor/bundle
# 20180506 for whenever probrem
# RUN echo "gem 'whenever'" >> Gemfile
RUN bundle install

#postgresql setup
ADD user.sql /my_enju/user.sql
COPY pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
# RUN echo "listen_addresses='*'" >> /etc/postgresql/9.6/main/postgresql.conf
COPY database.yml /my_enju/config/database.yml

RUN /etc/init.d/postgresql start && \
    su postgres -c 'psql -f user.sql' && \
    bundle exec rake db:create:all

RUN echo SECRET_KEY_BASE=`bundle exec rake secret` >> .env
RUN echo RAILS_SERVE_STATIC_FILES=true >> .env
RUN echo REDIS_URL=redis://127.0.0.1/enju_leaf >> .env

RUN /etc/init.d/postgresql start && \
    rails g enju_leaf:setup &&\
    RAILS_ENV=production rails g enju_leaf:quick_install
# RUN bundle exec whenever --update-crontab

RUN    echo solr: bundle exec rake sunspot:solr:run > Procfile \
    && echo resque: bundle exec rake environment resque:work QUEUE=enju_leaf,mailers TERM_CHILD=1 >> Procfile \
    && echo web: bundle exec rails s -b 0.0.0.0 -p 3000 >> Procfile

RUN echo RAILS_ENV=production >> .env

ADD enjustart.sh /my_enju/enjustart.sh
RUN chmod ug+x /my_enju/enjustart.sh
CMD /my_enju/enjustart.sh
EXPOSE 3000

