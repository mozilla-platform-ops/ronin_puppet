require 'puppet_x'
require 'pp'
require 'puppet/util'
require 'puppet/util/windows'
module PuppetX
  module WindowsFirewall

    MOD_DIR = "windows_firewall/lib"
    SCRIPT_FILE = "ps-bridge.ps1"
    SCRIPT_PATH = File.join("ps/windows_firewall", SCRIPT_FILE)


    # We need to be able to invoke the PS bridge script in both agent and apply
    # mode. In agent mode, the file will be found in LIBDIR, in apply mode it will
    # be found somewhere under CODEDIR. We need to read from the appropriate dir
    # for each mode to work in the most puppety way
    def self.resolve_ps_bridge

      case Puppet.run_mode.name
      when :user
        # AKA `puppet resource` - first scan modules then cache
        script = find_ps_bridge_in_modules || find_ps_bridge_in_cache
      when :apply
        # puppet apply demands local module install...
        script = find_ps_bridge_in_modules
      when :agent
        # agent mode would only look in cache
        script = find_ps_bridge_in_cache
      else
        raise("Don't know how to resolve #{SCRIPT_FILE} for windows_firewall in mode #{Puppet.run_mode.name}")
      end

      if ! script
        raise("windows_firewall unable to find #{SCRIPT_FILE} in expected location")
      end

      cmd = ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", script]
      cmd
    end

    def self.find_ps_bridge_in_modules
      # 1st priority - environment
      check_for_script = File.join(
          Puppet.settings[:environmentpath],
          Puppet.settings[:environment],
          "modules",
          MOD_DIR,
          SCRIPT_PATH,
          )
      Puppet.debug("Checking for #{SCRIPT_FILE} at #{check_for_script}")
      if File.exists? check_for_script
        script = check_for_script
      else
        # 2nd priority - custom module path, then basemodulepath
        full_module_path = "#{Puppet.settings[:modulepath]}#{File::PATH_SEPARATOR}#{Puppet.settings[:basemodulepath]}"
        full_module_path.split(File::PATH_SEPARATOR).reject do |path_element|
          path_element.empty?
        end.each do |path_element|
          check_for_script = File.join(path_element, MOD_DIR, SCRIPT_PATH)
          Puppet.debug("Checking for #{SCRIPT_FILE} at #{check_for_script}")
          if File.exists? check_for_script
            script = check_for_script
            break;
          end
        end
      end

      script
    end

    def self.find_ps_bridge_in_cache
      check_for_script = File.join(Puppet.settings[:libdir], SCRIPT_PATH)

      Puppet.debug("Checking for #{SCRIPT_FILE} at #{check_for_script}")
      script = File.exists?(check_for_script) ? check_for_script : nil
      script
    end

    # convert a puppet type key name to the argument to use for `netsh` command
    def self.global_argument_lookup(key)
      {
          :keylifetime       => "mainmode mmkeylifetime",
          :secmethods        => "mainmode mmsecmethods",
          :forcedh           => "mainmode mmforcedh",
          :strongcrlcheck    => "ipsec strongcrlcheck",
          :saidletimemin     => "ipsec saidletimemin",
          :defaultexemptions => "ipsec defaultexemptions",
          :ipsecthroughnat   => "ipsec ipsecthroughnat",
          :authzcomputergrp  => "ipsec authzcomputergrp",
          :authzusergrp      => "ipsec authzusergrp",
      }.fetch(key, key.to_s)
    end

    # convert a puppet type key name to the argument to use for `netsh` command
    def self.profile_argument_lookup(key)
      {
        :localfirewallrules         => "settings localfirewallrules",
        :localconsecrules           => "settings localconsecrules",
        :inboundusernotification    => "settings inboundusernotification",
        :remotemanagement           => "settings remotemanagement",
        :unicastresponsetomulticast => "settings unicastresponsetomulticast",
        :logallowedconnections      => "logging allowedconnections",
        :logdroppedconnections      => "logging droppedconnections",
        :filename                   => "logging filename",
        :maxfilesize                => "logging maxfilesize",
     }.fetch(key, key.to_s)
    end

    def self.to_ps(key)
      {
        :enabled               => lambda { |x| camel_case(x)},
        :action                => lambda { |x| camel_case(x)},
        :direction             => lambda { |x| camel_case(x)},
        :interface_type        => lambda { |x| x.map {|e| camel_case(e)}.join(",")},
        :profile               => lambda { |x| x.map {|e| camel_case(e)}.join(",")},
        :protocol              => lambda { |x| x.to_s.upcase.sub("V","v")},
        :icmp_type             => lambda { |x| camel_case(x)},
        :edge_traversal_policy => lambda { |x| camel_case(x)},
        :local_port            => lambda { |x| "\"#{camel_case(x)}\""},
        :remote_port           => lambda { |x| "\"#{camel_case(x)}\""},
        :local_address         => lambda { |x| "\"#{camel_case(x)}\""},
        :remote_address        => lambda { |x| "\"#{camel_case(x)}\""},
        :program               => lambda { |x| x.gsub(/\\/, '\\\\')},
        :authentication        => lambda { |x| camel_case(x)},
        :encryption            => lambda { |x| camel_case(x)},
        :remote_machine        => lambda { |x| convert_to_sddl(x)},
        :local_user            => lambda { |x| convert_to_sddl(x)},
        :remote_user           => lambda { |x| convert_to_sddl(x)},
      }.fetch(key, lambda { |x| x })
    end

    def self.to_ruby(key)
      {
        :enabled                => lambda { |x| snake_case_sym(x)},
        :action                 => lambda { |x| snake_case_sym(x)},
        :direction              => lambda { |x| snake_case_sym(x)},
        :interface_type         => lambda { |x| x.split(",").map{ |e| snake_case_sym(e.strip)}},
        :profile                => lambda { |x| x.split(",").map{ |e| snake_case_sym(e.strip)}},
        :protocol               => lambda { |x| snake_case_sym(x)},
        :icmp_type              => lambda { |x| x ? x.downcase : x },
        :edge_traversal_policy  => lambda { |x| snake_case_sym(x)},
        :program                => lambda { |x| x.gsub(/\\\\/, '\\')},
        :remote_port            => lambda { |x| x.downcase },
        :local_port             => lambda { |x| x.downcase },
        :remote_address         => lambda { |x| x.downcase },
        :local_address          => lambda { |x| x.downcase },
        :authentication         => lambda { |x| x.downcase },
        :encryption             => lambda { |x| x.downcase },
        :remote_machine         => lambda { |x| convert_from_sddl(x)},
        :local_user             => lambda { |x| convert_from_sddl(x)},
        :remote_user            => lambda { |x| convert_from_sddl(x)},
      }.fetch(key, lambda { |x| x })
    end

    # Convert name to SID and structure result as SDDL value
    def self.convert_to_sddl_acl(value,ace)
      # we need to convert users to sids first
      sids = []
      value.split(',').sort.each do |name|
        name.strip!
        sid = Puppet::Util::Windows::SID.name_to_sid(name)
        #If resolution failed, thrown a warning
        if sid.nil?
          warn("\"#{value}\" does not exist")
        else
          #Generate structured SSDL ACL
          cur_sid = '('+ ace +';;CC;;;' + sid + ')'
        end
        sids << cur_sid unless cur_sid.nil?
      end
      sids.sort.join('')
    end

    # Convert name to SID and structure result as SDDL value
    def self.convert_to_sddl(value)
      'O:LSD:' + (convert_to_sddl_acl(value['allow'],'A') unless value['allow'].nil?).to_s + (convert_to_sddl_acl(value['block'],'D') unless value['block'].nil?).to_s
    end
  
    # Parse SDDL value and convert SID to name
    def self.convert_from_sddl(value)
      if value == 'Any'
        #Return value in lowercase
        value.downcase!
      else
        # we need to convert users to sids first
        # Delete prefix
        value.delete_prefix! 'O:LSD:'
        # Change ')(' to ',' to have a proper delimiter
        value.gsub! ')(', ','
        # Remove '()'
        value.delete! '()'
        #Define variables
        names = {}
        allow = []
        deny = []
        value.split(',').sort.each do |sid|
          #ACE is first character
          ace = sid.chr.upcase
          #Delete prefix on each user
          sid.delete_prefix! ace + ';;CC;;;'
          sid.strip!
          name = Puppet::Util::Windows::SID.sid_to_name(sid)
          #If resolution failed, return SID
          if name.nil?
            cur_name = sid.downcase!
          else
            cur_name = name.downcase!
          end
          case ace
            when 'A'
              allow << cur_name unless cur_name.nil?
            when 'D'
              deny << cur_name unless cur_name.nil?
          end
        end
        if !allow.empty?
          names['allow'] = allow.sort.join(',')
        end
        if !deny.empty?
          names['block'] = deny.sort.join(',')
        end
        names
      end
    end

    # create a normalised key name by:
    # 1. lowercasing input
    # 2. converting spaces to underscores
    # 3. convert to symbol
    def self.key_name(input)
      input.downcase.gsub(/\s/, "_").to_sym
    end

    # Convert input CamelCase to snake_case symbols
    def self.snake_case_sym(input)
      input.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
    end

    # Convert snake_case input symbol to CamelCase string
    def self.camel_case(input)
      # https://stackoverflow.com/a/24917606/3441106
      input.to_s.split('_').collect(&:capitalize).join
    end

    def self.delete_rule(name)
      Puppet.notice("(windows_firewall) deleting rule '#{name}'")
      out = Puppet::Util::Execution.execute(resolve_ps_bridge + ["delete", name]).to_s
      Puppet.debug out
    end

    def self.update_rule(resource)
      Puppet.notice("(windows_firewall) updating rule '#{resource[:name]}'")

      # `Name` is mandatory and also a `parameter` not a `property`
      args = [ "-Name", resource[:name] ]
      
      resource.properties.reject { |property|
        [:ensure, :protocol_type, :protocol_code].include?(property.name) ||
            property.value == :none
      }.each { |property|
        # All properties start `-`
        property_name = "-#{camel_case(property.name)}"
        property_value = to_ps(property.name).call(property.value)

        # protocol can optionally specify type and code, other properties are set very simply
        args << property_name
        args << property_value
      }
      Puppet.debug "Updating firewall rule with args: #{args}"

      out = Puppet::Util::Execution.execute(resolve_ps_bridge + ["update"] + args)
      Puppet.debug out
    end

    # Create a new firewall rule using powershell
    # @see https://docs.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule?view=win10-ps
    def self.create_rule(resource)
      Puppet.notice("(windows_firewall) adding rule '#{resource[:name]}'")

      # `Name` is mandatory and also a `parameter` not a `property`
      args = [ "-Name", resource[:name] ]
      
      resource.properties.reject { |property|
        [:ensure, :protocol_type, :protocol_code].include?(property.name) ||
            property.value == :none
      }.each { |property|
        # All properties start `-`
        property_name = "-#{camel_case(property.name)}"
        property_value = to_ps(property.name).call(property.value)

        # protocol can optionally specify type and code, other properties are set very simply
        args << property_name
        args << property_value
      }
      Puppet.debug "Creating firewall rule with args: #{args}"

      out = Puppet::Util::Execution.execute(resolve_ps_bridge + ["create"] + args)
      Puppet.debug out
    end

    def self.rules
      Puppet.debug("query all rules")
      rules = JSON.parse Puppet::Util::Execution.execute(resolve_ps_bridge + ["show"]).to_s
      
      # Rules is an array of hash as-parsed and hash keys need converted to
      # lowercase ruby labels
      puppet_rules = rules.map { |e|
        Hash[e.map { |k,v|
          key = snake_case_sym(k)
          [key, to_ruby(key).call(v)]
        }].merge({ensure: :present})
      }
      Puppet.debug("Parsed rules: #{puppet_rules.size}")
      puppet_rules
    end

    def self.groups
      Puppet.debug("query all groups")
      # get all individual firewall rules, then create a new hash containing the overall group
      # status for each group of rules
      g = {}
      rules.select { |e|
        # we are only interested in firewall rules that provide grouping information so bounce
        # anything that doesn't have it from the list
        ! e[:display_group].empty?
      }.each { |e|
        # extract the group information for each rule, use the value of :enabled to
        # build up an overall status for the whole group. Dont forget that the
        # value is a label :true or :false - to fit with puppet's newtype operator
        k = e[:display_group]
        current = g.fetch(k, e[:enabled])

        if current == :true && e[:enabled] == :true
          g[k] = :true
        else
          g[k] = :false
        end

      }

      # convert into puppet's preferred hash format which is an array of hashes
      # with each hash representing a distinct resource
      transformed = g.map { |k,v|
        {:name => k, :enabled => v}
      }

      Puppet.debug("group rules #{transformed}")
      transformed
    end


    # Each rule is se
    def self.parse_profile(input)
      profile = {}
      first_line = true
      profile_name = "__error__"
      input.split("\n").reject { |line|
        line =~ /---/ || line =~ /^\s*$/
      }.each { |line|
        if first_line
          # take the first word in the line - eg "public profile settings" -> "public"
          profile_name = line.split(" ")[0].downcase
          first_line = false
        else
          # nasty hack - "firewall policy" setting contains space and will break our
          # logic below. Also the setter in `netsh` to use is `firewallpolicy`. Just fix it...
          line = line.sub("Firewall Policy", "firewallpolicy")

          # split each line at most twice by first glob of whitespace
          line_split = line.split(/\s+/, 2)

          if line_split.size == 2
            key = key_name(line_split[0].strip)

            # downcase all values for comparison purposes
            value = line_split[1].strip.downcase

            profile[key] = value
          end
        end
      }

      # if we see the rule then it must exist...
      profile[:name] = profile_name

      Puppet.debug "Parsed windows firewall profile: #{profile}"
      profile
    end

    # Each rule is se
    def self.parse_global(input)
      globals = {}
      input.split("\n").reject { |line|
        line =~ /---/ || line =~ /^\s*$/
      }.each { |line|

        # split each line at most twice by first glob of whitespace
        line_split = line.split(/\s+/, 2)

        if line_split.size == 2
          key = key_name(line_split[0].strip)

          # downcase all values for comparison purposes
          value = line_split[1].strip.downcase

          case key
          when :secmethods
            # secmethods are output with a hypen like this:
            #   DHGroup2-AES128-SHA1,DHGroup2-3DES-SHA1
            # but must be input with a colon like this:
            #   DHGroup2:AES128-SHA1,DHGroup2:3DES-SHA1
            safe_value = value.split(",").map { |e|
              e.sub("-", ":")
            }.join(",")
          when :strongcrlcheck
            safe_value = value.split(":")[0]
          when :defaultexemptions
            safe_value = value.split(",").sort
          when :saidletimemin
            safe_value = value.sub("min","")
          when :ipsecthroughnat
            safe_value = value.gsub(" ","")
          else
            safe_value = value
          end

          globals[key] = safe_value
        end
      }

      globals[:name] = "global"

      Puppet.debug "Parsed windows firewall globals: #{globals}"
      globals
    end

    # parse firewall profiles
    def self.profiles(cmd)
      profiles = []
      # the output of `show allprofiles` contains several blank lines that make parsing somewhat
      # harder so just run it for each of the three profiles to make life easy...
      ["publicprofile", "domainprofile", "privateprofile"].each { |profile|
        profiles <<  parse_profile(Puppet::Util::Execution.execute([cmd, "advfirewall", "show", profile]).to_s)
      }
      profiles
    end


    # parse firewall profiles
    def self.globals(cmd)
      profiles = []
      # the output of `show allprofiles` contains several blank lines that make parsing somewhat
      # harder so just run it for each of the three profiles to make life easy...
      ["publicprofile", "domainprofile", "privateprofile"].each { |profile|
        profiles <<  parse_global(Puppet::Util::Execution.execute([cmd, "advfirewall", "show", "global"]).to_s)
      }
      profiles
    end
  end
end