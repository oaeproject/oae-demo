FROM ubuntu:20.04
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/London"

RUN chsh -s /bin/bash \
        && apt-get update \
        && apt-get install -y --no-install-recommends apt-transport-https \
        && apt-get -y upgrade \
        && apt-get install -y --no-install-recommends \
        curl \
        gcc \
        g++ \
        git \
        vim \
        gnupg \
        python \
        apt-utils \
        libvips \
        software-properties-common \
        debconf-utils \
        apt-transport-https \
        lsb-release \
        make \
        ca-certificates \
        fonts-liberation \
        libappindicator3-1 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libc6 \
        libcups2 \
        libexpat1 \
        libgbm1 \
        libgcc1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libstdc++6 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxrandr2 \
        libxss1 \
        xdg-utils \
        gconf-service \
        libasound2 \
        libcairo2 \
        libdbus-1-3 \
        libfontconfig1 \
        libgconf-2-4 \
        libgdk-pixbuf2.0-0 \
        libxrender1 \
        libxtst6 \
        libappindicator1 \
        # Install OAE supporting software
        redis-server \
        nginx \
        openjdk-8-jre-headless \
        libreoffice \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Install and set up elasticsearch
RUN \
        curl https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.0-amd64.deb --output elasticsearch-7.9.0-amd64.deb \
        && dpkg -i elasticsearch-7.9.0-amd64.deb \
        && printf "\nnetwork.host: 127.0.0.1" >> /etc/elasticsearch/elasticsearch.yml

# Install and set up Cassandra
RUN \
        curl https://downloads.apache.org/cassandra/2.1.22/apache-cassandra-2.1.22-bin.tar.gz --output apache-cassandra-2.1.22-bin.tar.gz \
        &&  tar -xzvf apache-cassandra-2.1.22-bin.tar.gz \
        && mv apache-cassandra-2.1.22 /usr/local/cassandra \
        && adduser --group cassandra ; adduser --shell /bin/bash --gecos "" --ingroup cassandra --disabled-password cassandra \
        && usermod -aG cassandra cassandra \
        && chown root:cassandra -R /usr/local/cassandra/ \
        && chmod g+w -R /usr/local/cassandra/ \
        && echo "cassandra_parms=\"-Dcassandra.logdir=$CASSANDRA_HOME/logs\"" >> /usr/local/cassandra/bin/cassandra \
        && adduser --group node ; adduser --shell /bin/bash --gecos "" --ingroup node --disabled-password node

# Install chromium (unsafe PPA)
RUN \
        add-apt-repository ppa:saiarcot895/chromium-beta \
        && apt-get update \
        && apt-get install -y --no-install-recommends chromium-browser \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install and setup node and pm2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN \
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
        && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
        && apt-get install -y --no-install-recommends nodejs \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        && npm install -g npm@7.0.8

# Change user from now on
USER node

# Set the Hilary directory
ENV CODE_DIR /home/node
WORKDIR ${CODE_DIR}

# Clone and set up Hilary
RUN git clone https://github.com/oaeproject/Hilary.git

# Set up paths as environment variables
ENV HILARY_DIR ${CODE_DIR}/Hilary
ENV UI_DIR ${HILARY_DIR}/3akai-ux
ENV ETHERCALC_DIR ${HILARY_DIR}/ethercalc

# Update submodules
WORKDIR ${HILARY_DIR}
RUN git submodule sync ; git submodule update --init

# Costumise Hilary configuration
WORKDIR ${HILARY_DIR}
RUN \
        { \
        printf "\nconfig.cassandra.hosts = ['localhost'];";                                \
        printf "\nconfig.cassandra.timeout = 9000;";                                       \
        printf "\nconfig.redis.host = 'localhost';";                                       \
        printf "\nconfig.search.nodes = ['http://localhost:9200'];";                       \
        printf "\nconfig.mq.host = 'localhost';";                                          \
        printf "\nconfig.previews.enabled = true;";                                        \
        printf "\nconfig.email.debug = false;";                                            \
        printf "\nconfig.email.transport = 'sendmail';";                                   \
        printf "\nconfig.previews.office.binary = '/usr/bin/soffice';";                    \
        printf "\nconfig.previews.screenShotting.binary = '/usr/bin/chromium-browser';";   \
        printf "\nconfig.previews.screenShotting.sandbox = '--no-sandbox';";               \
        } >> config.js

# Set up Etherpad
WORKDIR ${HILARY_DIR}
RUN \
        sed -i 's/oae-cassandra/localhost/g'       ep-settings.json \
        && sed -i 's/oae-redis/localhost/g'        ep-settings.json \
        && cp ep-settings.json                     etherpad/settings.json \
        && cp ep-package.json                      etherpad/src/package.json \
        && cp ep-root-package.json                 etherpad/package.json

# Set up Ethercalc
WORKDIR ${HILARY_DIR}
RUN cp ec-package.json ethercalc/package.json

# Create the temp directory for Hilary
ENV TMP_DIR ${HILARY_DIR}/tmp
RUN \
        mkdir -p ${TMP_DIR} \
        ; mkdir -p ${TMP_DIR}/previews \
        ; mkdir -p ${TMP_DIR}/uploads \
        ; mkdir -p ${TMP_DIR}/files \
        ; chown -R node:node ${TMP_DIR} \
        ; chmod -R 777 ${TMP_DIR} \
        ; export TMP=${TMP_DIR} \
        ; chown -R node:node ${CODE_DIR} \
        ; chmod -R 777 ${CODE_DIR}

# Install ethercal deps
WORKDIR ${ETHERCALC_DIR}
RUN npm install

# Install etherpad deps
WORKDIR ${HILARY_DIR}
RUN ./prepare-etherpad.sh

# Install 3akai-ux deps
WORKDIR ${UI_DIR}
RUN npm install

# Install Hilary deps
WORKDIR ${HILARY_DIR}
RUN npm install

# Setup PM2
RUN sed -i 's/\/opt\/current/\/home\/node\/Hilary/g' process.json

# Install cqlsh for testing
RUN \
        curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py \
        ; python get-pip.py \
        ; ~/.local/bin/pip install cqlsh \
        ; echo "CREATE KEYSPACE IF NOT EXISTS \"etherpad\" WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1 };" >> init.cql

USER root

# Set up nginx
WORKDIR ${HILARY_DIR}
RUN \
        openssl req -x509 -nodes -days 3650 -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acme.com" -newkey rsa:2048 -keyout ${UI_DIR}/nginx/nginx-selfsigned.key -out ${UI_DIR}/nginx/nginx-selfsigned.crt \
        && openssl dhparam -out ${UI_DIR}/nginx/dhparam.pem 2048 \
        && sed -i 's/host.docker.internal/localhost/g'                             ${UI_DIR}/nginx/nginx.docker.conf \
        && sed -i 's/oae-etherpad/localhost/g'                                     ${UI_DIR}/nginx/nginx.docker.conf \
        && sed -i 's/oae-ethercalc/localhost/g'                                    ${UI_DIR}/nginx/nginx.docker.conf \
        && sed -i 's/\/usr\/src\//\/home\/node\//g'                                ${UI_DIR}/nginx/nginx.docker.conf \
        && sed -i 's/\/usr\/share\/files/\/home\/node\/Hilary\/tmp\/files/g'       ${UI_DIR}/nginx/nginx.docker.conf \
        && cp ${UI_DIR}/nginx/nginx.docker.conf                                    ${UI_DIR}/nginx/nginx.conf \
        && cp ${UI_DIR}/nginx/nginx.conf               /etc/nginx/ \
        && cp ${UI_DIR}/nginx/mime.conf                /etc/nginx/ \
        && cp ${UI_DIR}/nginx/self-signed.conf         /etc/nginx/ \
        && cp ${UI_DIR}/nginx/ssl-params.conf          /etc/nginx/ \
        && cp ${UI_DIR}/nginx/dhparam.pem              /etc/nginx/ \
        && cp ${UI_DIR}/nginx/nginx-selfsigned.key     /etc/nginx/ \
        && cp ${UI_DIR}/nginx/nginx-selfsigned.crt     /etc/nginx/ \
        && cp ${UI_DIR}/nginx/dhparam.pem              /etc/nginx/

# Set up environment variables Hilary needs to start
RUN \
        { \
        echo export RECAPTCHA_KEY=yada yada; \
        echo export TWITTER_KEY=yada yada; \
        echo export TWITTER_SECRET=yada yada; \
        echo export FACEBOOK_APP_ID=yada yada; \
        echo export FACEBOOK_APP_SECRET=yada yada; \
        echo export GOOGLE_CLIENT_ID=yada yada; \
        echo export GOOGLE_CLIENT_SECRET=yada yada; \
        echo export ETHEREAL_USER=yada yada; \
        echo export ETHEREAL_PASS=yada yada; \
        echo export TMP=/home/node/Hilary/tmp; \
        } >> /home/node/.profile;

# 80:   Nginx HTTP
# 443:  Nginx HTTPS
# 2000: Hilary admin worker
# 2001: Hilary worker
# 6379: Redis service
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 8000: Ethercalc service
# 9001: Etherpad service
# 9042: CQL
# 9160: thrift service
EXPOSE 80 443 2000 2001 6379 7000 7001 7199 8000 9001 9042 9160

# Run the app - you may override CMD via docker run command line instruction
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 /usr/local/cassandra/bin/cassandra > /usr/local/cassandra/cassandra.log ; service elasticsearch start ; service redis-server start ; service nginx start ; runuser -l node -c 'cd Hilary ; npm run migrate ; ~/.local/bin/cqlsh -f init.cql ; npx pm2 startOrReload process.json ; npx pm2 logs'"]
