class linux_gui_wayland (
  $builder_user,
  $builder_group,
  $builder_home
) {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '24.04': {
          # TODO: do something here... at a minimum set a resolution
        }
        default: {
          fail ("linux_gui_wayland does not support Ubuntu version ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("linux_gui_wayland is not supported on ${facts['os']['name']}")
    }
  }
}
