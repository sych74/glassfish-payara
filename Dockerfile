# FROM java:8-jdk
#FROM devbeta/java-openjdk:openjdk-1.8.0
FROM devbeta/jdk:1.8.0_102
MAINTAINER "info@jelastic.com"

# ENV or ARG?

### -= PAYARA =- ###
#ENV APP_VERSION 4.1.1.171.0.1
#ARG APP_URL=https://s3-eu-west-1.amazonaws.com/payara.fish/Payara+Downloads/Payara+$APP_VERSION/payara-$APP_VERSION.zip
#ENV APP_PATH /opt/payara
#ENV APP_USER payara
#ARG APP_NAME=Payara

### -= GLASSFISH =- ###
ENV APP_VERSION=4.1.1
ARG APP_URL=http://download.oracle.com/glassfish/${APP_VERSION}/release/glassfish-${APP_VERSION}.zip
ENV APP_PATH /opt/glassfish
ENV APP_USER glassfish
ARG APP_NAME=GlassFish
### -= END =- ###

#################################
ENV APP_PKG_FILE_NAME application-$APP_VERSION.zip
ARG ADMIN_USER=admin
ARG ADMIN_PASSWORD=admin
ENV HOME_DIR $APP_PATH/home
ENV PSWD_FILE $HOME_DIR/glassfishpwd

# RUN \
#  yum -y update && \
#  yum install -y unzip

RUN wget --quiet -O /opt/$APP_PKG_FILE_NAME $APP_URL \
	&& unzip -qq /opt/$APP_PKG_FILE_NAME -d /opt \
	&& rm /opt/$APP_PKG_FILE_NAME \
	&& ln -s /opt/$(ls /opt/ -1 | head -n1) $APP_PATH

RUN mkdir -p $APP_PATH/deployments
RUN useradd -b /opt -m -s /bin/bash -d $HOME_DIR $APP_USER && echo $APP_USER:$APP_USER | chpasswd
RUN chown -R $APP_USER:$APP_USER /opt



COPY install-root.sh /install-root.sh
RUN bash /install-root.sh

ADD src/. /
RUN mkdir -p /etc/jelastic/; echo -e "# This file is considered only during container creation. To modify the list of items at Favorites panel,\n\
# please make the required changes within image initial settings and rebuild it.\n\
\n\
[directories]\n\
$APP_PATH/glassfish/domains/domain1/config\n\
$APP_PATH/glassfish/domains/domain1/lib\n\
$APP_PATH/glassfish/lib\n\
$APP_PATH/home\n\
/usr/java/latest\n\
/var/lib/jelastic/keys\n\
/var/spool/cron\n\
[files]\n\
/etc/jelastic/redeploy.conf\n\
" >> /etc/jelastic/favourites.conf

RUN echo -e "COMPUTE_TYPE=$APP_USER\n\
COMPUTE_TYPE_VERSION=${APP_VERSION%%.*}\n\
COMPUTE_TYPE_FULL_VERSION=$APP_VERSION\n\
PLATFORM_TECHMAIL_RECEPIENT=admin@nonexistentdomainxxx.com\n\
" >> /etc/jelastic/metainf.conf

RUN echo -e "# This file stores links to custom configuration files or folders that will be kept during container redeploy.\n\
\n\
/etc/jelastic/redeploy.conf\n\
/etc/sysconfig/iptables\n\
/etc/sysconfig/iptables-custom\n\
/var/lib/jelastic/keys\n\
/var/spool/cron/glassfish\n\
" >> /etc/jelastic/redeploy.conf

RUN mkdir /tmp/jem_install; wget -O /tmp/jem_install/jem.zip 'https://github.com/jelastic/jem/archive/5.0.6.zip' && \
 unzip -o /tmp/jem_install/jem.zip -d /tmp/jem_install && \
 /bin/cp -rf /tmp/jem_install/jem-5.0.6/* / && rm -rf /tmp/jem_install

COPY init.script /etc/init.d/glassfish-domain1
COPY start.sh $HOME_DIR/start.sh
RUN chmod a+x $HOME_DIR/start.sh /etc/init.d/glassfish-domain1
USER $APP_USER
# WORKDIR $APP_PATH

# set credentials to admin/admin

RUN echo -e 'AS_ADMIN_PASSWORD=\n\
AS_ADMIN_NEWPASSWORD='$ADMIN_PASSWORD'\n\
EOF\n'\
>> /opt/tmpfile

RUN echo -e 'AS_ADMIN_PASSWORD='$ADMIN_PASSWORD'\n\
EOF\n'\
>> $HOME_DIR/glassfishpwd

RUN \
 $APP_PATH/bin/asadmin start-domain && \
 $APP_PATH/bin/asadmin --user $ADMIN_USER --passwordfile=/opt/tmpfile change-admin-password && \
 $APP_PATH/bin/asadmin --user $ADMIN_USER --passwordfile=$HOME_DIR/glassfishpwd enable-secure-admin && \
 $APP_PATH/bin/asadmin restart-domain


WORKDIR /etc/init.d
# Default ports to expose
EXPOSE 4848 8009 8080 8181
################################################ check for payara
LABEL actions="customSSL highAvailability webAccess" \
    adminUrl="https://das-{env-name}:4848" \
    appUser=$APP_USER \
    cloudletsMinCount=6 \
    cloudletsCount=6 \
    contextRegex="^((([a-zA-Z0-9])+((-|_|\.{1})([a-zA-Z0-9])+)+)|([a-zA-Z0-9]+))$" \
    description="Jelastic $APP_NAME docker" \
    distrib=centos7 \
    jem=1 \
    logFolder="$APP_PATH/glassfish/domains/domain1/logs" \
    name=$APP_NAME \
    nodeType=${APP_USER} \
    nodeVersion=${APP_VERSION}


# cleanup
RUN rm /opt/tmpfile

# Start asadmin console and the domain
CMD ["glassfish-domain1", "start"]
