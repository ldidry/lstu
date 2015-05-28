# Lstu

## What Lstu means ?

It means Let's Shorten That Url.

## License

Lstu is licensed under the terms of the WTFPL. See the LICENSE file.

## Dependancies

* Carton : Perl dependencies manager, it will get what you need, so don't bother for dependencies (but you can read the file `cpanfile` if you want).

```shell
sudo cpan Carton
```

## Installation
After installing Carton :

```shell
git clone https://git.framasoft.org/luc/lstu.git
cd lstu
carton install
cp lstu.conf.template lstu.conf
```

## Usage

```
carton exec hypnotoad script/lstu
```

Yup, that's all, it will listen at "http://127.0.0.1:8080".

For more options (interfaces, user, etc.), change the configuration in `lstu.conf` (have a look at http://mojolicio.us/perldoc/Mojo/Server/Hypnotoad#SETTINGS for the available options).

## Other options

There is the `contact` option (mandatory), where you have to put some way for the users to contact you, and the `secret` where you have to put a random string in order to protect your Mojolicious cookies (not really useful and optional).

Please, have a look at the `lstu.conf.template`, it's full of options and self-documented.

## How many urls can it handle ?

By default, there are 8 361 453 672 available combinations. I think the sqlite db will explode before you reach this limit. If you want more shortened URLs than that, open `lstu.conf` and change the `length` setting.

Everytime somebody uses Lstu, it will create 'waiting' shortened URLs codes in order to be quick to shorten the URLs.

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

You can use a reverse proxy like Nginx or Varnish (or Apache with the mod\_proxy module). The web is full of tutos.

## Internationalization

Lstu comes with English and French languages. It will choose the language to display with the browser's settings.

If you want to add more languages, please help on <https://www.transifex.com/projects/p/lstu/>

There are just a few sentences, so it will be quick to translate.

If you add sentences to translate, just do `make locales` to update the en.po file and don't forget to update the others translation files.

## Official instance

You can see it working and use it at https://lstu.fr.

## API

See https://lstu.fr/api

## Others projects dependencies

Lstu is written in Perl with the Mojolicious framework and uses the Twitter bootstrap framework to look not too ugly.
