class statsd {
  include nodejs

  user { 'statsd':
    gid        => 'statsd',
    ensure     => present,
    shell      => $shell,
    managehome => false,
  }
  group { 'statsd':
    ensure => present,
  }

  File {
    owner   => 'statsd',
    group   => 'statsd',
    mode    => 755,
    require => [User['statsd'], Group['statsd']],
  }

  package { 'git':
    ensure => installed,
  } ->

  vcsrepo { "/opt/statsd/":
    ensure   => present,
    provider => git,
    source   => "git://github.com/etsy/statsd.git",
  } ->

  file {
  'confdir':
    ensure => directory,
    path   => '/etc/statsd';
  'logdir':
    ensure => directory,
    path   => '/var/log/statsd';
  } ->

  file {
  'localConfig.js':
    ensure  => file,
    path    => '/etc/statsd/localConfig.js',
    content => template('statsd/localConfig.js.erb');
  'statsd.log':
    ensure  => file,
    path    => '/var/log/statsd/statsd.log';
  'statsd.upstart':
    ensure  => file,
    path    => '/etc/init/statsd.conf',
    content => template('statsd/statsd.upstart.erb');
  } ->

  service { 'statsd':
    ensure  => running,
    require => Class['nodejs'],
  }
}

