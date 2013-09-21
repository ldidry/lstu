#LSTU

##What LSTU means ?
It means Let's Shorten That Url.

##License
Lstu is licensed under the terms of the WTFPL. See the LICENSE file

##Dependancies
* Carton : Perl dependancies manager, it will get what you need, so don't bother for dependancies (but you can read the cpanfile if you want)

```
sudo cpan Carton
```

##Installation
After installing Carton :
```
git clone https://github.com/ldidry/lstu.git
cd lstu
carton install
```

##Usage
```
carton exec ./Lstu daemon -m production
```

Yup, that's all, it will listen at "http://\*:3000".

For more options (interfaces, user, etc.), run :
```
carton exec ./Lstu help daemon
```

##How many urls can it handle ?
Well, there is 8 361 453 672 available combinations. I think the sqlite db will explod before you reach this limit. If you want more shortened URLs than that, open the Lstu file and change
```
$shortener->(8)
```
with a higher number.

##Reverse proxy
You can use a reverse proxy like Nginx or Varnish (or Apache with the mod\_proxy module). The web is full of tutos.

##Others projects dependancies
Lstu is written in Perl with the Mojolicious framework and uses the Twitter bootstrap framework to look not too ugly.
