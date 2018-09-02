FROM debian:stretch
MAINTAINER tuyoshia
# Get noninteractive frontend for Debian to avoid some problems:
#    debconf: unable to initialize frontend: Dialog
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get -y upgrade
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre
RUN apt-get -y install openjdk-8-jre-headless
RUN apt-get -y install ruby ruby-dev
RUN apt-get -y install imagemagick libicu-dev unzip git libxslt1-dev build-essential nodejs redis-server
RUN apt-get -y install zlib1g-dev
RUN apt-get -y install postgresql libpq-dev
RUN gem install rails -v=4.2.10
RUN gem install foreman
RUN rm -rf /var/lib/apt/lists/* 

# install enju
# RUN rails new my_enju -m https://gist.github.com/5357321.txt -d postgresql --skip-bundle
RUN rails _4.2.10_ new my_enju -d postgresql --skip-bundle \
    -m https://gist.github.com/nabeta/8024918f41242a16719796c962ed2af1.txt
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

RUN echo RAILS_ENV=production > .env
RUN echo SECRET_KEY_BASE=`bundle exec rake secret` >> .env
RUN echo RAILS_SERVE_STATIC_FILES=true >> .env
RUN echo REDIS_URL=redis://127.0.0.1/enju_leaf >> .env

RUN /etc/init.d/postgresql start && \
    su postgres -c 'psql -f user.sql' && \
    bundle exec rake db:create:all && \
    rails g enju_leaf:setup && \
    RAILS_ENV=production rails g enju_leaf:quick_install
# RUN bundle exec whenever --update-crontab

RUN    echo solr: bundle exec rake sunspot:solr:run > Procfile \
    && echo resque: bundle exec rake environment resque:work QUEUE=enju_leaf TERM_CHILD=1 >> Procfile \
    && echo web: bundle exec rails s -b 0.0.0.0 >> Procfile
ADD enjustart.sh /my_enju/enjustart.sh
RUN chmod ug+x /my_enju/enjustart.sh
CMD /my_enju/enjustart.sh
EXPOSE 3000

