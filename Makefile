EXTRACTFILES=utilities/locales_files.txt
EN=lib/Lstu/I18N/en.po
FR=lib/Lstu/I18N/fr.po
XGETTEXT=carton exec local/bin/xgettext.pl

locales:
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(EN)
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(FR)
