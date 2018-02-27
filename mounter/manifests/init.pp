class mounter( Hash $mounts = undef ){

  file { '/usr/local/bin/ebs-attacher.rb':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/mounter/ebs-attacher.rb',
  }
  create_resources(mounter::with_ebs,$mounts)

}
