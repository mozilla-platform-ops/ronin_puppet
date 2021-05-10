# @summary
#  A plan that retrieves facts and stores in the inventory for the
#  specified targets.
#
# @param targets List of targets to retrieve the facts for.
# @return ResultSet of Task results.
plan facts(TargetSpec $targets) {
  $result_set = run_task('facts', $targets)

  $result_set.each |$result| {
    add_facts($result.target, $result.value)
  }

  return $result_set
}
