##############################################################################
#
#  Copyright (C) 2010 Robert Longstaff (rob@longstaff.us)
#  
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; either version 2 of the License, or
#      (at your option) any later version.
#  
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#  
#      You should have received a copy of the GNU General Public License along
#      with this program; if not, write to the Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
##############################################################################

INSTALL=/usr/bin/install -c
INSTALL_OPTS=

# TODO Split dirs/handling to allow for / prefix installs
prefix=/usr/local/reagent
exec_prefix=${prefix}

SRC_LIB=lib

INIT_DIR=/etc/init.d

all: 
	cd $(SRC_LIB); $(MAKE) ; cd ..

clean: 
	rm -f var/*.log var/*.pid

install-client: 
	cd $(SRC_LIB); $(MAKE) $@ ; cd ..
	$(INSTALL) -m 755 $(INSTALL_OPTS) rack $(DESTDIR)$(prefix)
	$(INSTALL) -m 644 $(INSTALL_OPTS) etc/rack.cfg $(DESTDIR)$(prefix)/etc

install-server: 
	cd $(SRC_LIB); $(MAKE) $@ ; cd ..
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(INIT_DIR)
	$(INSTALL) -m 755 $(INSTALL_OPTS) rc.d/reagentd $(DESTDIR)$(INIT_DIR)
	
	$(INSTALL) -m 750 $(INSTALL_OPTS) -d $(DESTDIR)$(prefix)
	$(INSTALL) -m 750 $(INSTALL_OPTS) -d $(DESTDIR)$(prefix)/etc
	$(INSTALL) -m 750 $(INSTALL_OPTS) -d $(DESTDIR)$(prefix)/libexec
	$(INSTALL) -m 750 $(INSTALL_OPTS) -d $(DESTDIR)$(prefix)/var
	$(INSTALL) -m 755 $(INSTALL_OPTS) reagentd $(DESTDIR)$(prefix)
	$(INSTALL) -m 755 $(INSTALL_OPTS) depcheck $(DESTDIR)$(prefix)
	$(INSTALL) -m 644 $(INSTALL_OPTS) etc/reagentd.cfg $(DESTDIR)$(prefix)/etc
	$(INSTALL) -m 644 $(INSTALL_OPTS) etc/reagentd_log.cfg $(DESTDIR)$(prefix)/etc

