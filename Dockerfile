FROM ubuntu:18.04

ENV bpcver 4.3.0
ENV bpcxsver 0.58
ENV rsyncbpcver 3.0.9.13
ENV password test

# Needed only when installing
RUN apt-get update
RUN apt-get install -q -y apache2 apache2-utils libapache2-mod-perl2 glusterfs-client par2 perl smbclient rsync tar sendmail gcc zlib1g zlib1g-dev libapache2-mod-scgi rrdtool git make perl-doc libarchive-zip-perl libfile-listing-perl libxml-rss-perl libcgi-session-perl libacl1-dev
#echo -n "Give password or leave empty to generate one: "
#read -s PASSWORD
#echo
#if [[ $PASSWORD == "" ]]; then
#  apt-get -qq -y install pwgen
#  PASSWORD=`pwgen -s -1 32`
#  echo "Generated password: $PASSWORD"
#else
#  echo "Password given is: $PASSWORD"
#fi
RUN echo "$PASSWORD" > /root/password
RUN chmod 600 /root/password
RUN mkdir /srv/backuppc
RUN ln -s /srv/backuppc/ /var/lib/backuppc
RUN adduser --system --home /var/lib/backuppc --group --disabled-password --shell /bin/false backuppc
#RUN echo "backuppc:$PASSWORD" | sudo chpasswd backuppc
RUN mkdir -p /var/lib/backuppc/.ssh
RUN chmod 700 /var/lib/backuppc/.ssh
RUN echo -e "BatchMode yes\nStrictHostKeyChecking no" > /var/lib/backuppc/.ssh/config
RUN ssh-keygen -q -t rsa -b 4096 -N '' -C "BackupPC key" -f /var/lib/backuppc/.ssh/id_rsa
RUN chmod 600 /var/lib/backuppc/.ssh/id_rsa
RUN chmod 644 /var/lib/backuppc/.ssh/id_rsa.pub
RUN chown -R backuppc:backuppc /var/lib/backuppc/.ssh

RUN apt-get -y install wget

# Fetch and install latest stable releases
RUN wget https://github.com/backuppc/backuppc-xs/releases/download/$bpcxsver/BackupPC-XS-$bpcxsver.tar.gz && \
	wget https://github.com/backuppc/rsync-bpc/releases/download/$rsyncbpcver/rsync-bpc-$rsyncbpcver.tar.gz && \
	wget https://github.com/backuppc/backuppc/releases/download/$bpcver/BackupPC-$bpcver.tar.gz && \
	tar -zxf BackupPC-XS-$bpcxsver.tar.gz && \
	tar -zxf rsync-bpc-$rsyncbpcver.tar.gz && \
	tar -zxf BackupPC-$bpcver.tar.gz && \
	cd BackupPC-XS-$bpcxsver && \
	perl Makefile.PL && \
	make && \
	make test && \
	make install && \
	cd ../rsync-bpc-$rsyncbpcver && \
	./configure && \
	make && \
	make install && \
	cd ../BackupPC-$bpcver

# To fetch and install the latest development code instead, replace the above section with:
#git clone https://github.com/backuppc/backuppc.git
#git clone https://github.com/backuppc/backuppc-xs.git
#git clone https://github.com/backuppc/rsync-bpc.git
#cd backuppc-xs
#perl Makefile.PL
#make
#make test
#make install
#cd ../rsync-bpc
#./configure
#make
#make install
#cd ../backuppc
#./makeDist --nosyntaxCheck --releasedate "`date -u "+%d %b %Y"`" --version ${bpcver}git
#tar -zxf dist/BackupPC-${bpcver}git.tar.gz
#cd BackupPC-${bpcver}git

# When installing, use this
RUN cd ../BackupPC-$bpcver && ./configure.pl --batch --cgi-dir /var/www/cgi-bin/BackupPC --data-dir /var/lib/backuppc --hostname backuppc --html-dir /var/www/html/BackupPC --html-dir-url /BackupPC --install-dir /usr/local/BackupPC

# When upgrading, use this instead:
# ./configure.pl --batch --config-path /etc/BackupPC/config.pl

# The following is good also when upgrading, unless you have modified the files yourself
RUN cd ../BackupPC-$bpcver && cp httpd/BackupPC.conf /etc/apache2/conf-available/backuppc.conf
RUN cd ../BackupPC-$bpcver && sed -i "/deny\ from\ all/d" /etc/apache2/conf-available/backuppc.conf
RUN cd ../BackupPC-$bpcver && sed -i "/deny\,allow/d" /etc/apache2/conf-available/backuppc.conf
RUN cd ../BackupPC-$bpcver && sed -i "/allow\ from/d" /etc/apache2/conf-available/backuppc.conf

# Note that changing the apache user and group (next two commands) could cause other services
# provided by apache to fail. There are alternatives if you don't want to change the apache
# user: use SCGI or a setuid BackupPC_Admin script - see the docs.
RUN cd ../BackupPC-$bpcver && sed -i "s/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=backuppc/" /etc/apache2/envvars
RUN cd ../BackupPC-$bpcver && sed -i "s/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=backuppc/" /etc/apache2/envvars
RUN cd ../BackupPC-$bpcver && echo '<html><head><meta http-equiv="refresh" content="0; url=/BackupPC_Admin"></head></html>' > /var/www/html/index.html
RUN a2enconf backuppc
RUN a2enmod cgid
RUN service apache2 restart

RUN cd ../BackupPC-$bpcver && cat systemd/init.d/debian-backuppc 

#RUN cp systemd/init.d/debian-backuppc /etc/init.d/backuppc
#RUN chmod 755 /etc/init.d/backuppc
#RUN update-rc.d backuppc defaults
#RUN chmod u-s /var/www/cgi-bin/BackupPC/BackupPC_Admin
RUN touch /etc/BackupPC/BackupPC.users
RUN sed -i "s/$Conf{CgiAdminUserGroup}.*/$Conf{CgiAdminUserGroup} = 'backuppc';/" /etc/BackupPC/config.pl
RUN sed -i "s/$Conf{CgiAdminUsers}.*/$Conf{CgiAdminUsers} = 'backuppc';/" /etc/BackupPC/config.pl
RUN chown -R backuppc:backuppc /etc/BackupPC

# Needed only when installing
RUN echo $PASSWORD | htpasswd -i /etc/BackupPC/BackupPC.users backuppc

CMD /usr/local/BackupPC/bin/BackupPC
