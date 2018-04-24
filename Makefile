EXTRACTDIR=-D lib -D themes/default
POT=themes/default/lib/Lstu/I18N/lstu.pot
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
REAL_LSTU=script/application
LSTU=script/lstu

minify:
	@echo "CSS concatenation"
	@cd ./themes/default/public/css/   && cat bootstrap.min.css lstu.css fontelico.css | csso > bootstrap-lstu.min.css
	@cd ./themes/milligram/public/css/ && cat milligram.min.css lstu.css ../../../default/public/css/fontelico.css | csso > milli-lstu.min.css

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(POT) 2>/dev/null
	cd ./themes/milligram && make locales

push-locales:
	zanata-cli -q -B push

pull-locales:
	zanata-cli -q -B pull

stats-locales:
	zanata-cli -q stats

podcheck:
	podchecker lib/Lstu/DB/Ban.pm lib/Lstu/DB/Session.pm lib/Lstu/DB/URL.pm

cover:
	PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' $(CARTON) cover --ignore_re '^local'

test:
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' $(CARTON) $(REAL_LSTU) test

test-sqlite:
	@rm -rf test1.db test1.db-journal cover_db/
	@echo 'MOJO_CONFIG=t/sqlite1.conf'
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' MOJO_CONFIG=t/sqlite1.conf $(CARTON) $(REAL_LSTU) test
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' $(CARTON) cover --ignore_re '^local'

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
