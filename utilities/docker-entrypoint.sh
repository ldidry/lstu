#!/bin/bash
# vim: set ts=4 sts=4 sw=4 et:

# Must have a /data directory to hold important configuration, etc.
if [[ ! -d '/data' ]]; then
    echo 'ERROR: Directory /data not found' >&2
    echo 'Please mount it from your Docker host system using a Docker volume' >&2
    exit 1
fi

# Must be owned by daemon:daemon
if [[ "$(stat --format='%U:%G' '/data')" != 'daemon:daemon' ]]; then
    echo 'ERROR: directory /data must be owned by user/group daemon:daemon' >&2
    echo 'Please run "sudo chown -R 1:1 /path/to/data" on your host system' >&2
    exit 1
fi

# Copy default configuration file if one does not exist
if [[ ! -f '/data/lstu.conf' ]]; then
    echo 'Generating minimal configuration file: /data/lstu.conf'
    echo 'Please see lstu.conf.template and customize as necessary.'
    cat > /data/lstu.conf << EOF
# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
{
    ############################################################################
    # Default Docker Configuration File
    ############################################################################

    hypnotoad => {
        listen => ['http://0.0.0.0:8080'],
        pid_file => '/tmp/hypnotoad.pid',
    },

    contact => 'admin[at]example.com',
    dbtype => 'sqlite',
    db_path => '/data/lstu.db',
};
EOF
fi

# Run Lstu
export MOJO_CONFIG='/data/lstu.conf'
exec carton exec hypnotoad -f script/lstu
