EN=lib/Lstu/I18N/en.po
FR=lib/Lstu/I18N/fr.po
SEDOPTS=-e "s@SOME DESCRIPTIVE TITLE@Lstu language file@" \
		-e "s@YEAR THE PACKAGE'S COPYRIGHT HOLDER@2015 Luc Didry@" \
		-e "s@CHARSET@utf8@" \
		-e "s@the PACKAGE package@the Lstu package@" \
		-e '/^\#\. (/{N;/\n\#\. (/{N;/\n.*\.\.\/default\//{s/\#\..*\n.*\#\./\#. (/g}}}' \
		-e '/^\#\. (/{N;/\n.*\.\.\/default\//{s/\n/ /}}'
SEDOPTS2=-e '/^\#.*\.\.\/default\//,+3d'
XGETTEXT=carton exec ../../local/bin/xgettext.pl
CARTON=carton exec

locales:
		$(XGETTEXT) -D templates -D ../default/templates -o $(EN) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(FR) 2>/dev/null
		sed $(SEDOPTS) -i $(EN)
		sed $(SEDOPTS2) -i $(EN)
		sed $(SEDOPTS) -i $(FR)
		sed $(SEDOPTS2) -i $(FR)
