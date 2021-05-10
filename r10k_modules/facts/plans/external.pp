# @summary
#   A plan that generates external facts based on the provided modulepath and
#   sets facts on specified targets.
#
# @param path The path to the directory on localhost containing external facts
# @param targets The targest the collect and set facts on
# @return The target objects, with facts added
# @example Gather external facts from an installed module
#   $moduledir = module_directory('mymod')
#   $with_facts = run_plan(facts::external, $targets, path => file::join($moduledir, 'facts.d'))
#   return $with_facts.map |$target| { $target.facts }
plan facts::external(
  String $path,
  TargetSpec $targets
) {
  $t = get_targets($targets)

  # Strip out dotfiles
  $facts_paths = dir::children($path).filter |$path| { $path[0] != '.' }
  $facts_paths.each |$file| {
    $ext_facts = run_script(file::join($path, $file), $t)
    $t.each |$target| {
      $raw_facts = $ext_facts.find($target.name).value['stdout']
      $jsonoryaml = catch_errors() || {
        parseyaml($raw_facts)
      }

      # If parsing as YAML or JSON failed, the error will be a string and we
      # should try to parse the original facts as key-value pairs
      if type($jsonoryaml, 'generalized') == String {
          $fact_kv_strings = $raw_facts.split(/\n/)
          $fact_kvs = $fact_kv_strings.map |$str| {
            $match = $str.match(/^([^=]+)=(.+)$/)
            if $match {
                $key = $match[1]
                $value = $match[2]
            } else {
              $msg = @("MSG"/L)
              External fact output must have key-value pairs separated by an '=' on each line, like so:
              key=value
              key2=value2
              | MSG
              fail_plan($msg)
            }
            [$key, $value]
          }
        $facts_for_target = Hash.new($fact_kvs.flatten)
        add_facts($target, $facts_for_target)
      } else {
        # If the result of parsing as YAML isn't a string, assume it's a struct
        add_facts($target, $jsonoryaml)
      }
    }
  }

  return $t
}
