class plugin_cinder_eqlx
{
    include cinder::params

    $primary_controller = $::fuel_settings['role'] ? { 'primary-controller'=>true, default=>false }
    $default_volume_type = $::fuel_settings['cinder_eqlx']['default_volume_type']

    if $::fuel_settings['storage']['volumes_ceph'] {
      $enabled_backends = ['cinder_ceph','cinder_eqlx']
    }
    else {
      $enabled_backends = ['cinder_eqlx']
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
      'DEFAULT/ssh_min_pool_conn': value => 1;
      'DEFAULT/ssh_max_pool_conn': value => 1;
    }


    class { 'cinder::backends':
      enabled_backends    => $enabled_backends,
      default_volume_type => $default_volume_type,
    }

    service { $::cinder::params::volume_service:
      ensure => running,
      enable => true,
    }

    Cinder::Backend::Eqlx['cinder_eqlx'] ->
      Cinder_config['DEFAULT/ssh_min_pool_conn'] ->
        Cinder_config['DEFAULT/ssh_max_pool_conn'] ->
          Class['cinder::backends'] ~>
            Service[$::cinder::params::volume_service]

    if $primary_controller {

      package {'python-cinderclient':
        ensure => present,
      }

      cinder::type { 'eqlx':
        os_username     => $::fuel_settings['access']['user'],
        os_password     => $::fuel_settings['access']['password'],
        os_tenant_name  => $::fuel_settings['access']['tenant'],
        os_auth_url     => "http://${::fuel_settings['management_vip']}:5000/v2.0/",
        set_key         => 'volume_backend_name',
        set_value       => 'cinder_eqlx',
      }

      Package['python-cinderclient'] ->
        Class['cinder::backends'] ->
          Cinder::Type['eqlx']
    }

}
