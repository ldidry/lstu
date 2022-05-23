# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DefaultConfig;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($default_config);
our $default_config = {
    prefix                 => '/',
    provisioning           => 100,
    provis_step            => 5,
    length                 => 8,
    secret                 => ['hfudsifdsih'],
    really_delete_urls     => 0,
    page_offset            => 10,
    theme                  => 'default',
    ban_min_strike         => 3,
    ban_whitelist          => [],
    ban_blacklist          => [],
    minion                 => {
        enabled => 0,
        db_path => 'minion.db'
    },
    session_duration       => 3600,
    disable_api            => 0,
    dbtype                 => 'sqlite',
    db_path                => 'lstu.db',
    max_redir              => 2,
    skip_spamhaus          => 0,
    safebrowsing_api_key   => '',
    memcached_servers      => [],
    x_frame_options        => 'DENY',
    x_content_type_options => 'nosniff',
    x_xss_protection       => '1; mode=block',
    log_creator_ip         => 0,
    qrcode_size            => 3,
};

1;
