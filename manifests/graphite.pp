class statsd::graphite {
  $apt_pkgs = [
    'python',
    'memcached',
    'python-dev',
    'python-pip',
    'sqlite3',
    'libcairo2',
    'libcairo2-dev',
    'python-cairo',
    'pkg-config',
    'nginx',
  ]

  package { $apt_pkgs:
    ensure => present,
  } ->

  package {
    'django':
      provider => 'pip',
      ensure   => '1.3';
    ['python-memcached',
     'django-tagging',
     'twisted',
     'carbon',
     'whisper',
     'graphite-web']:
      provider => 'pip',
      ensure   => latest;
  }

  file {
    'storage-schemas.conf':
      ensure  => file,
      path    => '/opt/graphite/conf/storage-schemas.conf',
      require => Package['carbon', 'graphite-web', 'whisper'],
      content => template('statsd/storage-schemas.conf.erb');
    ['/opt/graphite/storage', '/opt/graphite/storage/log', '/opt/graphite/storage/log/webapp']:
      ensure  => directory,
      require => File['storage-schemas.conf'],
      mode    => 777;
    'carbon.conf':
      ensure  => file,
      source  => '/opt/graphite/conf/carbon.conf.example',
      path    => '/opt/graphite/conf/carbon.conf',
      require => Package['carbon'];
    'local_settings.py':
      ensure  => file,
      source  => '/opt/graphite/webapp/graphite/local_settings.py.example',
      path    => '/opt/graphite/webapp/graphite/local_settings.py',
      require => Package['carbon', 'graphite-web', 'whisper'];
  }

  exec { 'init db':
    command => 'python manage.py syncdb --noinput',
    cwd     => '/opt/graphite/webapp/graphite',
    require => File['local_settings.py']
  }

  file { 'graphite.db':
    ensure => present,
    owner  => 'www-data',
    group  => 'www-data',
    path   => '/opt/graphite/storage/graphite.db',
  }

  exec { 'carbon-cache':
    command => 'python ./bin/carbon-cache.py start',
    cwd     => '/opt/graphite',
    require => [Exec['init db'], File['carbon.conf', 'local_settings.py', 'storage-schemas.conf']], #, 'graphite.db']],
  }

  include uwsgi

  uwsgi::resource::app { "django":
    options        => {
      "module"     => "django.core.handlers.wsgi:WSGIHandler()",
      "socket"     => "127.0.0.1:3031",
      "processes"  => "1",
      "master"     => "true",
      "chdir"      => "/opt/graphite/webapp",
      "env"        => "DJANGO_SETTINGS_MODULE=graphite.settings",
    }
  }

  file {
    'graphite.nginx':
      ensure  => file,
      path    => '/etc/nginx/sites-available/graphite',
      content => template('statsd/graphite.nginx.erb'),
      require => Package['nginx'];
    #'uwsgi_params':
    #  ensure  => file,
    #  path    => '/etc/nginx/uwsgi_params',
    #  content => template('statsd/uwsgi_params.erb'),
    #  require => Package['nginx'];
  } ->

  file {
    'enable nginx graphite site':
      ensure => link,
      path   => '/etc/nginx/sites-enabled/graphite',
      source => '/etc/nginx/sites-available/graphite';
    'disable nginx default site':
      ensure => absent,
      path   => '/etc/nginx/sites-enabled/default';
  } ->

  service {'nginx':
    ensure => running,
  }

}
