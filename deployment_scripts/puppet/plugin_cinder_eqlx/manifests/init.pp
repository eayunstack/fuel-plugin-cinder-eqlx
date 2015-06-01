class plugin_cinder_eqlx
{
    include cinder::params

    $set_type = 'eqlx'
    $set_key = 'volume_backend_name'
    $set_value = 'cinder_eqlx'
    $os_username = $::fuel_settings['access']['user']
    $os_password = $::fuel_settings['access']['password']
    $os_tenant_name = $::fuel_settings['access']['tenant']
    # no matter whether deployment_mode is ha or not, management_vip is always in astute.yaml
    $os_auth_url = "http://${::fuel_settings['management_vip']}:5000/v2.0/"
    $default_volume_type = $::fuel_settings['cinder_eqlx']['default_volume_type']

    $ha_mode = $::fuel_settings['deployment_mode'] ? { /^(ha|ha_compact)$/  => true, default => false}
    if $ha_mode {
      $primary_controller = $::fuel_settings['role'] ? { 'primary-controller' => true, default => false }
    }
    else {
      # There is no primary_controller when deployment_mode is not ha.
      $primary_controller = true
    }

    if $::fuel_settings['storage']['volumes_ceph'] {
      $enabled_backends = ['cinder_ceph','cinder_eqlx']
    }
    else {
      $enabled_backends = ['cinder_eqlx']
    }

    package {$::cinder::params::package_name:
      ensure => present,
    }

    cinder::backend::eqlx { 'cinder_eqlx':
      san_ip                    => $::fuel_settings['cinder_eqlx']['san_ip'],
      san_login                 => $::fuel_settings['cinder_eqlx']['san_login'],
      san_password              => $::fuel_settings['cinder_eqlx']['san_password'],
      eqlx_group_name           => $::fuel_settings['cinder_eqlx']['eqlx_group_name'],
      eqlx_pool                 => $::fuel_settings['cinder_eqlx']['eqlx_pool'],
      san_thin_provision        => true,
      volume_backend_name       => 'cinder_eqlx',
      eqlx_use_chap             => false,
      eqlx_cli_timeout          => 30,
      eqlx_cli_max_retries      => 5,
    }

    cinder_config {
      'cinder_eqlx/ssh_min_pool_conn': value => 1;
      'cinder_eqlx/ssh_max_pool_conn': value => 1;
    }

    class { 'cinder::backends':
      enabled_backends    => $enabled_backends,
      default_volume_type => $default_volume_type,
    }

    service { $::cinder::params::api_service:
      ensure => running,
      enable => true,
    }

    service { $::cinder::params::volume_service:
      ensure => running,
      enable => true,
    }

    service { $::cinder::params::scheduler_service:
      ensure => running,
      enable => true,
    }

    Package[$::cinder::params::package_name] ->
      Cinder::Backend::Eqlx['cinder_eqlx'] ->
        Cinder_config['cinder_eqlx/ssh_min_pool_conn'] ->
          Cinder_config['cinder_eqlx/ssh_max_pool_conn'] ->
            Class['cinder::backends'] ~>
              Service[$::cinder::params::api_service] ~>
                Service[$::cinder::params::scheduler_service] ~>
                  Service[$::cinder::params::volume_service]

    if $primary_controller {

      package {$::cinder::params::client_package:
        ensure => present,
      }

      exec {"cinder type-create ${set_type}":
        path        => '/usr/bin',
        command     => "cinder type-create ${set_type} && cinder type-key ${set_type} set ${set_key}=${set_value}",
        environment => [
          "OS_TENANT_NAME=${os_tenant_name}",
          "OS_USERNAME=${os_username}",
          "OS_PASSWORD=${os_password}",
          "OS_AUTH_URL=${os_auth_url}",
        ],
        require     => Package[$::cinder::params::client_package],
        onlyif      => 'cinder --retries 10 type-list',
      }
    }
}
