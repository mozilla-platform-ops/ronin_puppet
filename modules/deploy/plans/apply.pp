plan deploy::apply (
  TargetSpec $targets,
  Boolean    $noop = false,
) {
    get_targets($targets).each |$target| {
        out::message("${target.name} => ${target.facts['puppet_role']}")
        # TODO: ensure all targets have puppet roles otherwise fail
    }
    out::message('Executing this plan will puppetize the targets')
    out::message("Puppet noop is ${noop}")


    $response = prompt('Continue executing plan? [Yes\No]')
    if $response != 'Yes' {
        fail_plan('User aborted plan execution!')
    }

    $targets.apply_prep

    apply($targets, '_catch_errors' => false, '_noop' => $noop, '_run_as' => 'root') {
        $role = $facts['puppet_role']
        include "roles_profiles::roles::${role}"
    }
}
