#LSTU

##What LSTU means ?
It means Let's Shorten That Url.

##License
Lstu is licensed under the terms of the WTFPL. See the LICENSE file.

##Dependancies
* Carton : Perl dependancies manager, it will get what you need, so don't bother for dependencies (but you can read the file `cpanfile` if you want).

```shell
sudo cpan Carton
```

##Installation
After installing Carton :
```shell
git clone https://github.com/ldidry/lstu.git
cd lstu
carton install
cp lstu.conf.template lstu.conf
```

##Usage
```
carton exec hypnotoad script/lstu
```

Yup, that's all, it will listen at "http://127.0.0.1:8080".

For more options (interfaces, user, etc.), change the configuration in `lstu.conf` (have a look at http://mojolicio.us/perldoc/Mojo/Server/Hypnotoad#SETTINGS for the available options).

##How many urls can it handle ?
Well, by default, there are 8 361 453 672 available combinations. I think the sqlite db will explode before you reach this limit. If you want more shortened URLs than that, open `lstu.conf` and change the `length` setting.

Everytime somebody uses LSTU, it will create 'waiting' shortened URLs codes in order to be quick to shorten the URLs.

Accordingly to the `lstu.conf` configuration file, it will create `provisionning` waiting URLs, adding them `provis_step` by `provis_step`.

This provisionning asks to modify your database if your updating LSTU from 0.01 to 0.02:
```shell
sqlite3 lstu.db
```

```SQL
PRAGMA writable_schema = 1;
UPDATE SQLITE_MASTER SET SQL = 'CREATE TABLE lstu (short TEXT PRIMARY KEY, url TEXT, counter INTEGER, timestamp INTEGER)' WHERE NAME = 'lstu';
PRAGMA writable_schema = 0;
```

##Other options
Well, there is the `contact` option, where you have to put some way for the users to contact you, and the `secret` where you have to put a random string in order to protect your Mojolicious cookies (not really useful and optional).

##Reverse proxy
You can use a reverse proxy like Nginx or Varnish (or Apache with the mod\_proxy module). The web is full of tutos.

##Internationalization
LSTU comes with English and French languages. It will choose the language to display with the browser's settings.

If you want to add more languages, for example German:
```shell
cd lib/I18N
cp en.pm de.pm
vim de.pm
```

There are just a few sentences, so it will be quick to translate. Please consider to send me you language file in order to help the other users :smile:.

##Official instance
You can see it working and use it at http://lstu.fr.

##API
You can shorten an URL with a GET request:
`http://lstu.fr/a?lsturl=http://example.com&format=json`

With `format=json`, you will get a json string like that:
`{"short":"http:\/\/lstu.fr\/XuHRAT6P","success":true,"url":"http:\/\/example.com"}`

If you don't use `format=json`, you will be redirected to http://lstu.fr where the shortened URL information will be displayed.

##Others projects dependancies
Lstu is written in Perl with the Mojolicious framework and uses the Twitter bootstrap framework to look not too ugly.
