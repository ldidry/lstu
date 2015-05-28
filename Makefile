EXTRACTFILES=utilities/locales_files.txt
EXTRACTTO=lib/Lstu/I18N/en.po
XGETTEXT=carton exec local/bin/xgettext.pl

locales:
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(EXTRACTTO)
