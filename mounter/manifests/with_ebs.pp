define mounter::with_ebs( 
  $ensure        = 'mounted',
  $atboot        = true,
  $device        = undef,
  $fstype        = undef,
  $options       = 'defaults,nobootwait',
  $remounts      = true,
  $with_ebs      = false,
  $ebs_name      = undef,
  $ebs_volume_id = undef,
  $dependencies  = undef,
  $mount_owner   = 'root',
  $mount_group   = 'root',
  $mount_mode    = '0755' )
{
  if ($ensure == 'mounted'){
    file { $name:
      ensure => directory,
      owner  => $mount_owner,
      group  => $mount_group,
      mode   => $mount_mode,
    }
  }

  if ($with_ebs == true) {
    exec { "${name}_ebs_attach":
      command => "/usr/local/bin/ebs-attacher.rb -d ${device} -n ${ebs_name} -r ${::aws_region}",
      require => [ File[$name], Package['aws-sdk'] , File['/usr/local/bin/ebs-attacher.rb'] ],
      before  => Mount[$name],
    }
  }
  
  mount { $name:
    ensure   => $ensure,
    device   => $device,
    atboot   => $atboot,
    options  => $options,
    before   => $dependencies,
    fstype   => $fstype,
    remounts => $remounts,
  }

}
