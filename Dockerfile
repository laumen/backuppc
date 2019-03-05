FROM centos:7

LABEL maintainer="Laurent"

ENV BACKUPPC_VERSION 4.3.0
ENV BACKUPPC_XS_VERSION 0.58
ENV RSYNC_BPC_VERSION master
ENV PAR2_VERSION v0.8.0
ENV WEB_BACKUPPC backuppc
ENV WEB_PASSWORD password
#ENV ROOT_PASSWORD root
ENV BACKUPPC_USERNAME backuppc
ENV BACKUPPC_GROUPNAME backuppc

#VOLUME ["/etc/backuppc", "/home/backuppc", "/data/backuppc", "/var/spool/cron/crontabs", "/etc/httpd"]
RUN echo "Test"

#Mise à jour
RUN \
    yum -y update \
    #Installations des dépendances
    && yum -y install httpd epel-release mod_ldap \
    && yum -y install perl-Archive-Zip perl-XML-RSS perl-CGI perl-File-Listing Perl-Test-Most \
    && yum -y install samba-client nfs-utils openssl \
    && yum -y install msmtp gcc gcc-c++ automake git perl-devel expat-devel atttr wget libacl-devel popt-devel \
    && yum -y install cronie \
    #Compiler et installer BACKUPPC-XS
    && git clone https://github.com/backuppc/backuppc-xs.git /root/backuppc-xs --branch $BACKUPPC_XS_VERSION \
    && cd /root/backuppc-xs \
    && perl Makefile.PL && make && make test && make install \
    #Compiler et installer RSYNC-BPC
    && git clone https://github.com/backuppc/rsync-bpc.git /root/rsync-bpc --branch $RSYNC_BPC_VERSION \
    && cd /root/rsync-bpc \
    && ./configure && make reconfigure && make && make install \
    #Compiler et installer PAR2
    && git clone https://github.com/Parchive/par2cmdline.git /root/par2cmdline --branch $PAR2_VERSION \
    && cd /root/par2cmdline \
    && ./automake.sh && ./configure && make && make check && make install \
    #Configurer MSMTP pour les mails
    && rm -f /usr/sbin/sendmail && ln -s /usr/bin/msmtp /usr/sbin/sendmail \
    #Télécharger BackupPC
    && curl -o /root/BackupPC-$BACKUPPC_VERSION.tar.gz -L https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz \
    #Créer le compte backuppc
    && mkdir -p /home/backuppc && cd /home/backuppc \
    && touch /firstrun \
    && rm -rf /root/backuppc-xs /root/rsync-bpc /root/par2cmdline

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80 22

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/sbin/apachectl", "-DFOREGROUND"]
CMD ["/usr/sbin/crond", "-f", "-d8"]
#CMD ["/usr/sbin/sshd", "-D", "-e"]
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
