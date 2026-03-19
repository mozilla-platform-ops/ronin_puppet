plan deploy::apply_no_verify (
  TargetSpec $targets,
  Boolean    $noop = false,
) {
    out::message('This plan will apply puppet to these hosts if noop is false:')
    get_targets($targets).each |$target| {
        out::message("${target.name} => ${target.facts['puppet_role']}")
        # TODO: ensure all targets have puppet roles otherwise fail
    }
    out::message("=== Puppet noop is ${noop}! ===")


    #$response = prompt('Continue executing plan? [Yes\No]')
    #if $response != 'Yes' {
    #    fail_plan('User aborted plan execution!')
    #}

    $targets.apply_prep

    apply($targets, '_catch_errors' => false, '_noop' => $noop, '_run_as' => 'root') {
        $role = $facts['puppet_role']
        include "roles_profiles::roles::${role}"
    }
}
