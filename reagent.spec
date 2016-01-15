
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

Summary: ReAgent remote agent
Name: reagent
Version: 0.1.1
Release: 1
Epoch: 0
Source0: reagent-%{version}.tar.gz
Group: Application/System
License: GPL
Group: PEI
BuildArchitectures: noarch
Buildroot: %{_tmppath}/%{name}-root
Requires: perl
Requires: perl(Readonly)
Requires: perl(FindBin::libs)
Requires: perl(Log::Log4perl)
Requires: perl(Config::General)
Requires: perl(Object::Trampoline)
Requires: perl(Proc::Reliable)
Requires: perl(Crypt::CBC)
Requires: perl(Crypt::OpenSSL::AES)
Prefix: /usr/local
AutoReq: 0

%description
A remote monitoring/managment agent to be used in conjunction with tools like
Nagios

%prep
%setup -q

%build
rm -rf $RPM_BUILD_ROOT
DESTDIR=$RPM_BUILD_ROOT make

%install
DESTDIR=$RPM_BUILD_ROOT make install-server

%clean
rm -fr $RPM_BUILD_ROOT

%post
if [ "$1" = "1" ]; then
    chkconfig --add reagentd
    chkconfig --level 345 reagentd on
fi
/etc/init.d/reagentd status >/dev/null
if [ "$?" -eq "0" ] ; then
    /etc/init.d/reagentd restart
fi

%preun
if [ "$1" = "0" ]; then
    /etc/init.d/reagentd status >/dev/null
    if [ "$?" -eq "0" ] ; then
        /etc/init.d/reagentd stop
    fi
    chkconfig --del reagentd
fi

%files
%defattr(-, root, root)
%dir /usr/local/reagent
%dir /usr/local/reagent/var
%dir /usr/local/reagent/libexec
%dir /usr/local/reagent/etc
/usr/local/reagent/lib
%config /usr/local/reagent/etc/reagentd.cfg
%config /usr/local/reagent/etc/reagentd_log.cfg
/etc/init.d/reagentd
/usr/local/reagent/reagentd
/usr/local/reagent/depcheck

%changelog
* Wed Jul 29 2009 Rob Longstaff <longstaff at playboy.com>
- Initial spec
