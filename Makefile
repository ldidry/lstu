EXTRACTFILES=utilities/locales_files.txt
EN=themes/default/lib/Lstu/I18N/en.po
FR=themes/default/lib/Lstu/I18N/fr.po
OC=themes/default/lib/Lstu/I18N/oc.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
REAL_LSTU=script/application
LSTU=script/lstu

locales:
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(EN) 2>/dev/null
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(FR) 2>/dev/null
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(OC) 2>/dev/null

podcheck:
	podchecker lib/Lstu/DB/Ban.pm lib/Lstu/DB/Session.pm lib/Lstu/DB/URL.pm

test: podcheck
	$(CARTON) $(REAL_LSTU) test

dev:
	$(CARTON) morbo $(LSTU) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lstu.conf

devlog:
	multitail log/development.log

minion:
	$(CARTON) $(REAL_LSTU) minion worker

installdeps:
	carton install

updatedeps:
	carton update
