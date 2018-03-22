# Lstu [![pipeline status](https://framagit.org/luc/lstu/badges/master/pipeline.svg)](https://framagit.org/luc/lstu/commits/master)

## What does Lstu mean?

It means Let's Shorten That Url.

## License

Lstu is licensed under the terms of the WTFPL. See the LICENSE file.

## Dependencies

* In order to compile some dependencies, you'll need some packages from your distro:

```shell
sudo apt-get install build-essential libssl-dev
```

* Carton : Perl dependencies manager, it will get what you need, so don't bother about dependencies (but you can read the file `cpanfile` if you want).

```shell
sudo cpan Carton
sudo cpan inc::Module::Install::DSL
```

* Install `libpq-dev`, `libmysqld-dev`, `libmariadbclient-dev` and `libpng-dev` too:

```shell
sudo apt-get install libpq-dev libmysqld-dev libmariadbclient-dev libpng-dev
```

## Installation

After installing Carton :

```shell
git clone https://framagit.org/luc/lstu.git
cd lstu
```

Let's continue the installation:

```shell
make installdeps
cp lstu.conf.template lstu.conf
# Edit the configuration file
vi lstu.conf
```

The configuration file is self-documented.

## Upgrade

```shell
cd /your/lstu/installation/directory
git pull
sudo apt-get install libpq-dev
```


Then:

```shell
make installdeps
vimdiff lstu.conf.template lstu.conf
```

Then reload the service manually (see below) or with your init system (`service lstu reload`).

## Usage

### Launch manually

This is good for test, not for production.

```
# start it
carton exec hypnotoad script/lstu
# reload it while running (yep, same command)
carton exec hypnotoad script/lstu
# stop it
carton exec hypnotoad -s script/lstu
```

Yup, that's all, it will listen at "http://127.0.0.1:8080".

For more options (interfaces, user, etc.), change the configuration in `lstu.conf` (have a look at http://mojolicio.us/perldoc/Mojo/Server/Hypnotoad#SETTINGS for the available options).

### Systemd

```
sudo su
cp utilities/lstu.service /etc/systemd/system/
vi /etc/systemd/system/lstu.service
systemctl daemon-reload
systemctl enable lstu.service
systemctl start lstu.service
```

### SysVinit

```
sudo su
cp utilities/lstu.default /etc/default/lstu
vi /etc/default/lstu
cp utilities/lstu.init /etc/init.d/lstu
update-rc.d lstu defaults
service lstu start
```

## Other options

There is the `contact` option (mandatory), where you have to put some way for the users to contact you, and the `secret` where you have to put a random string in order to protect your Mojolicious cookies (not really useful and optional).

Please, have a look at the `lstu.conf.template`, it's full of options and is self-documented.

## Heavily used instances

If your instance of Lstu is heavily used, you should take a look at the `minion` option: instead of updating the URL's counter right after a visit, this update is enqueued in [Minion](http://mojolicious.org/perldoc/Minion).

After enabling the use of Minion in `lstu.conf`, you'll need to start the queue processing daemon.
You can start it manually with `make minion`, but it's better to start it as a service.

Unfortunately for SysVinit users, I only created a systemd service file:

```
sudo su
cp utilities/lstu-minion@.service /etc/systemd/system/
vi /etc/systemd/system/lstu-minion@.service
systemctl daemon-reload
systemctl enable lstu-minion@1.service
systemctl start lstu-minion@1.service
```

You can see that this is a [template](https://fedoramagazine.org/systemd-template-unit-files/) unit file: you can start more than one minion worker with the same unit file.
You only need to enable it with an other name (`lstu-minion@1.service`, `lstu-minion@2.service`, etc.).

The more minion worker you will start, the quicker the job queue will be processed.
But be careful! As Lstu uses a SQLite database, too much workers will only lead to failures due to an `already locked database`.

Start with one worker, and add one if it's not enough to process the queue quick enough.

## How many URLs can it handle ?

By default, there are 8 361 453 672 available combinations. I think the sqlite db will explode before you reach this limit. If you want more shortened URLs than that, open `lstu.conf` and change the `length` setting.

Every time somebody uses Lstu, it will create 'waiting' shortened URLs codes in order to be quick to shorten the URLs.

Accordingly to the `lstu.conf` configuration file, it will create `provisioning` waiting URLs, adding them `provis_step` by `provis_step`.

This provisioning asks to modify your database if you're updating Lstu from 0.01 to 0.02:
```shell
sqlite3 lstu.db
```

```SQL
PRAGMA writable_schema = 1;
UPDATE SQLITE_MASTER SET SQL = 'CREATE TABLE lstu (short TEXT PRIMARY KEY, url TEXT, counter INTEGER, timestamp INTEGER)' WHERE NAME = 'lstu';
PRAGMA writable_schema = 0;
```

## Reverse proxy

For Nginx, use `utilities/lstu.nginx` as a template for your virtualhost configuration.

For Apache, use `utilities/lstu.apache` as a template for your virtualhost configuration.
Please note that this Apache template comes [from the community](https://framagit.org/luc/lstu/issues/12) and that there is **no official support for Apache**.

## Internationalization

Lstu comes with English, French and Occitan languages. It will choose the language to display with the browser's settings.

If you want to add more languages, please help on <https://www.transifex.com/projects/p/lstu/>

There are just a few sentences, so it will be quick to translate.

If you add sentences to translate, just do `make locales` to update the po files.

## Official instance

You can see it working and use it at https://lstu.fr.

## API

See https://lstu.fr/api

## Contributing

See the [contributing guidelines](CONTRIBUTING.md).

## Create new theme

Go to your Lstu directory and do:

```
carton exec ./script/lstu theme name_of_your_new_theme
```

It will create a skeleton in `themes` directory.

If you create a file with the same name and path as one in the default theme, it will prevail.
If you create a new file, it will be available.

If you want to translate strings from your theme (`<% l('To translate') %>`), go to your theme directory and do:

```
make locales
```

Then use the files in your theme's `lib/I18N` to translate your strings.

## Other projects dependencies

Lstu is written in Perl with the Mojolicious framework and uses the Twitter bootstrap framework to look not too ugly.

## Authors

See the [AUTHORS.md](AUTHORS.md) file.
