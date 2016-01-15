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

prefix=/usr/local/reagent
exec_prefix=${prefix}

INSTALL=/usr/bin/install -c
INSTALL_OPTS=
INIT_OPTS=

PERL_INC=${prefix}/lib
BASE_DIR=${PERL_INC}/Reagent

SNPRINTF_O=

all:

clean:
	rm -f core
	rm -f *~ 

distclean: clean

devclean: clean

install-common:
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Config
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Net
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Net/Filter
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Base.pm $(DESTDIR)$(BASE_DIR)
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Config.pm $(DESTDIR)$(BASE_DIR)
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/Socket.pm $(DESTDIR)$(BASE_DIR)/Net
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/Message.pm $(DESTDIR)$(BASE_DIR)/Net
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/Filter.pm $(DESTDIR)$(BASE_DIR)/Net
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/FilterSet.pm $(DESTDIR)$(BASE_DIR)/Net
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/Filter/AES.pm $(DESTDIR)$(BASE_DIR)/Net/Filter
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Net/Filter/CryptCBC.pm $(DESTDIR)$(BASE_DIR)/Net/Filter

install-client: install-common
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Client
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Config/Client.pm $(DESTDIR)$(BASE_DIR)/Config
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Client.pm $(DESTDIR)$(BASE_DIR)
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Client/Nagios.pm $(DESTDIR)$(BASE_DIR)/Client

install-server: install-common
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Server
	$(INSTALL) -m 755 $(INSTALL_OPTS) -d $(DESTDIR)$(BASE_DIR)/Server/Daemon
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Config/Daemon.pm $(DESTDIR)$(BASE_DIR)/Config
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Server.pm $(DESTDIR)$(BASE_DIR)
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Server/Daemon.pm $(DESTDIR)$(BASE_DIR)/Server
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Server/Nagios.pm $(DESTDIR)$(BASE_DIR)/Server
	$(INSTALL) -m 644 $(INSTALL_OPTS) Reagent/Server/Daemon/Connection.pm $(DESTDIR)$(BASE_DIR)/Server/Daemon

