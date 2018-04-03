#!/bin/bash
# vim: set ts=4 sts=4 sw=4 et:

# Must have a /lstu-data directory to hold important configuration, etc.
if [[ ! -d '/lstu-data' ]]; then
    echo 'ERROR: Directory /lstu-data not found' >&2
    echo 'Please mount it from your Docker host system using a Docker volume' >&2
    exit 1
fi

# Must be owned by daemon:daemon
if [[ "$(stat --format='%U:%G' '/lstu-data')" != 'daemon:daemon' ]]; then
    echo 'ERROR: directory /lstu-data must be owned by user/group daemon:daemon' >&2
    echo 'Please run "sudo chown -R 1:1 /path/to/lstu-data" on your host system' >&2
    exit 1
fi

# Copy default configuration file if one does not exist
if [[ ! -f '/lstu-data/lstu.conf' ]]; then
    echo 'Generating minimal configuration file: /lstu-data/lstu.conf'
    echo 'Please see lstu.conf.template and customize as necessary.'
    cat > /lstu-data/lstu.conf << EOF
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
    db_path => '/lstu-data/lstu.db',
};
EOF
fi

# Run Lstu
export MOJO_CONFIG='/lstu-data/lstu.conf'
exec carton exec hypnotoad -f script/lstu
