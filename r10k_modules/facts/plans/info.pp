# @summary
#   A plan that prints basic OS information for the specified targets. It first
#   runs the facts task to retrieve facts from the targets, then compiles the
#   desired OS information from the os fact value of each targets. This plan primarily
#   provides readable formatting, and ignores targets that error.
#
# @param targets List of the targets for which to print the OS information.
# @return List of strings formatted as "$target_name: $os"
plan facts::info(TargetSpec $targets) {
  return run_task('facts', $targets, '_catch_errors' => true).reduce([]) |$info, $r| {
    if ($r.ok) {
      $info + "${r.target.name}: ${r[os][name]} ${r[os][release][full]} (${r[os][family]})"
    } else {
      $info # don't include any info for targets which failed
    }
  }
}
