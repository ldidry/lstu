EXTRACTDIR=-D lib -D themes/default/templates
POT=themes/default/lib/Lstu/I18N/lstu.pot
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
REAL_LSTU=script/application
LSTU=script/lstu
HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,local

minify:
	@echo "CSS concatenation"
	@cd ./themes/default/public/css/   && cat bootstrap.min.css lstu.css fontelico.css | csso > bootstrap-lstu.min.css
	@cd ./themes/milligram/public/css/ && cat milligram.min.css lstu.css ../../../default/public/css/fontelico.css | csso > milli-lstu.min.css

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(POT) 2>/dev/null
	cd ./themes/milligram && make locales

podcheck:
	podchecker lib/Lstu/DB/*pm lib/Lstu/Command/*pm

check-syntax:
	find lib/ themes/ -name \*.pm -exec carton exec perl -Ilib -c {} \;
	find t/ -name \*.t -exec carton exec perl -Ilib -c {} \;

cover:
	PERL5OPT='-Ilib/' $(CARTON) cover --ignore_re '^local'

test:
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' $(CARTON) prove --comments --failures

test-junit-output:
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' $(CARTON) prove --comments --failures --formatter TAP::Formatter::JUnit > tap.xml

test-sqlite:
	@rm -rf test1.db test1.db-journal cover_db/
	@echo 'MOJO_CONFIG=t/sqlite1.conf'
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' MOJO_CONFIG=t/sqlite1.conf $(CARTON) prove --comments --failures
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' $(CARTON) cover --ignore_re '^local'

run-ldap-container:
	podman run -d --name rroemhild-test-openldap -p 127.0.0.1:10389:10389 docker.io/rroemhild/test-openldap

dev: minify
	$(CARTON) morbo $(LSTU) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lstu.conf

devlog:
	multitail log/development.log

minion:
	$(CARTON) $(REAL_LSTU) minion worker

installdeps:
	carton install

updatedeps:
	carton update
