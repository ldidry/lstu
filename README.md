# Lstu

## What does Lstu mean?

It means Let's Shorten That Url.

## License

Lstu is licensed under the terms of the WTFPL. See the LICENSE file.

## Installation

Please, see the [wiki](https://framagit.org/fiat-tux/hat-softwares/lstu/wikis/home).

Or you can see [usage with Docker](https://framagit.org/fiat-tux/hat-softwares/lstu/wikis/usage-with-docker).

## How many URLs can it handle ?

By default, there are 8 361 453 672 available combinations.

I think the sqlite db will explode before you reach this limit, but you can use PostgreSQL or MySQL as database instead of SQLite.

If you want more shortened URLs than that, open `lstu.conf` and change the `length` setting.

Every time somebody uses Lstu, it will create 'waiting' shortened URLs codes in order to be quick to shorten the URLs.

Accordingly to the `lstu.conf` configuration file, it will create `provisioning` waiting URLs, adding them `provis_step` by `provis_step`.

## Official instance

You can see it working and use it at <https://lstu.fr>. DOWN

## API

See <https://lstu.fr/api>.
Your instance will provide the same page with your URL.

## Contributing

See the [contributing guidelines](CONTRIBUTING.md).

## Other projects dependencies

Lstu is written in Perl with the Mojolicious framework and uses [Milligram](https://milligram.io/) CSS framework to look not too ugly.

## Authors

See the [AUTHORS.md](AUTHORS.md) file.
