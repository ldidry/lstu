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

test:
	$(CARTON) $(REAL_LSTU) test
	R=$?
	cat test.output
	exit $R

dev:
	$(CARTON) morbo $(LSTU) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lstu.conf

devlog:
	multitail log/development.log

installdeps:
	carton install

updatedeps:
	carton update
