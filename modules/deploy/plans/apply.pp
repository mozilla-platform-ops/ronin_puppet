plan deploy::apply (
  TargetSpec $targets,
  String     $role,
  Boolean    $noop = false,
) {

    $targets.apply_prep

    apply($targets, _catch_errors => false, _noop => $noop, _run_as => root) {
        include "roles_profiles::roles::${role}"
    }
}
