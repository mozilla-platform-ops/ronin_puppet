class roles_profiles::profiles::microsoft_store {
  case $facts['os']['name'] {
    'Windows': {
      include microsoft_store::init
      include microsoft_store::av1
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
