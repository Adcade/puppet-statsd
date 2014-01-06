class statsd::graphite {
  $apt_pkgs = [
#    'python',
    'memcached',
#    'python-dev',
#    'python-pip',
    'sqlite3',
    'libcairo2',
    'libcairo2-dev',
    'python-cairo',
    'pkg-config',
    #'nginx',
  ]

  package { $apt_pkgs:
    ensure => present,
  } ->

  package {
    'django':
      provider => 'pip',
      ensure   => '1.3';
    'twisted':
      provider => 'pip',
      ensure   => '13.1.0';
    ['python-memcached',
     'django-tagging',
     'carbon',
     'whisper',
     'graphite-web',
     'python-openid',
     'django-openid-auth']:
      provider => 'pip',
      ensure   => installed;
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
    unless  => 'python ./bin/carbon-cache.py status',
    cwd     => '/opt/graphite',
    require => [Exec['init db'], File['carbon.conf', 'local_settings.py', 'storage-schemas.conf']], #, 'graphite.db']],
  }

  include uwsgi

  uwsgi::resource::app { "django":
    options         => {
      "module"      => "django.core.handlers.wsgi:WSGIHandler()",
      "socket"      => "127.0.0.1:3031",
      "processes"   => "1",
      "master"      => "true",
      "chdir"       => "/opt/graphite/webapp",
      "env"         => "DJANGO_SETTINGS_MODULE=graphite.settings",
      "buffer-size" => "8196",
    }
  }

  include nginx

  nginx::site {
  "default":
    ensure => absent;
  "graphite":
    ensure  => present,
    content => template('statsd/graphite.nginx.erb'),
  }

  exec { "/usr/sbin/nginx -s reload":
    path      => ["/usr/bin/", "/usr/sbin", "/bin"],
    user      => root,
    subscribe => Nginx::Site["graphite"],
  }

}
