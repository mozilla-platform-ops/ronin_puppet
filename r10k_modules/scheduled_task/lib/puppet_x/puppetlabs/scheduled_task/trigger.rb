# frozen_string_literal: true

require 'time'

# module PuppetX
module PuppetX; end

# module PuppetX::PuppetLabs
module PuppetX::PuppetLabs; end

# @api private
# PuppetX::PuppetLabs::ScheduledTask module
module PuppetX::PuppetLabs::ScheduledTask
  # @api private
  # PuppetX::PuppetLabs::ScheduledTask::Trigger module
  module Trigger
    # Gets or sets the amount of time that is allowed to complete the task.
    class Duration
      # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
      # https://en.wikipedia.org/wiki/ISO_8601#Durations
      #
      # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
      # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
      # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
      # four days, two hours, and five minutes)
      def self.to_hash(duration)
        regex = %r{^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?(T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?)?$}

        matches = regex.match(duration)
        return nil if matches.nil?

        {
          year: matches['year'],
          month: matches['month'],
          day: matches['day'],
          minute: matches['minute'],
          hour: matches['hour'],
          second: matches['second'],
        }
      end

      # Converts a hash in a time format to seconds
      def self.hash_to_seconds(value)
        return 0 if value.nil?
        time = 0
        # Note - the Year and Month calculations are approximate
        time += value[:year].to_i   * (365.2422 * 24 * 60**2)      unless value[:year].nil?
        time += value[:month].to_i  * (365.2422 * 2 * 60**2)       unless value[:month].nil?
        time += value[:day].to_i    * 24 * 60**2                   unless value[:day].nil?
        time += value[:hour].to_i   * 60**2                        unless value[:hour].nil?
        time += value[:minute].to_i * 60                           unless value[:minute].nil?
        time += value[:second].to_i                                unless value[:second].nil?

        time.to_i
      end

      # Converts a hash in a time format to minutes
      def self.to_minutes(value)
        return 0 if value.nil?
        return 0 unless value.is_a?(String)
        return 0 if value.empty?

        duration = hash_to_seconds(to_hash(value))

        duration / 60
      end
    end

    # Converts a datetime to local time with no timezone
    def iso8601_datetime_to_local(value)
      return nil if value.nil?
      raise ArgumentError, 'value must be a String' unless value.is_a?(String)
      return nil if value.empty?

      # defaults to parsing as local with no timezone passed
      Time.parse(value).getlocal
    end
    module_function :iso8601_datetime_to_local

    # Scheduled Task manifest
    class Manifest
      # Valid Keys
      ValidKeys = [ # rubocop:disable Naming/ConstantName
        'index',
        'enabled',
        'schedule',
        'start_date',
        'start_time',
        'every',
        'months',
        'on',
        'which_occurrence',
        'day_of_week',
        'minutes_interval',
        'minutes_duration',
        'user_id',
        'disable_time_zone_synchronization',
      ].freeze

      # Valid Schedule Keys
      ValidScheduleKeys = [ # rubocop:disable Naming/ConstantName
        'once',
        'daily',
        'weekly',
        'monthly',
        'boot',
        'logon',
      ].freeze

      # https://msdn.microsoft.com/en-us/library/system.datetime.fromoadate(v=vs.110).aspx
      # d must be a value between -657435.0 (1/1/1753) through 2958465.99999999 (12/31/9999 11:59:59)
      MINIMUM_TRIGGER_DATE = Time.local(1753, 1, 1)

      # Formats time in a %Y-%-m-%-d format
      def self.format_date(time)
        time.strftime('%Y-%-m-%-d')
      end

      # Formats time to the ISO8601 %H:%M format
      def self.format_time(time)
        # equivalent to the ISO8601 %H:%M
        time.strftime('%R')
      end

      # Returns the default trigger setting for a specified schedule
      def self.default_trigger_settings_for(schedule = 'once')
        case schedule
        when 'once'
          {
            'schedule' => 'once',
          }
        when 'daily'
          {
            'schedule' => 'daily',
            'every'    => 1,
          }
        when 'weekly'
          {
            'schedule'     => 'weekly',
            'days_of_week' => V2::Day.names,
            'every'        => 1,
          }
        when 'monthly'
          {
            'schedule' => 'monthly',
            'months'   => V2::Month.indexes,
            'days'     => 0,
          }
        end
      end

      # Returns the default trigger for a specified schedule
      def self.default_trigger_for(schedule = 'once')
        now = Time.now
        {
          'enabled'             => true,
          'minutes_interval'    => 0,
          'minutes_duration'    => 0,
          'start_date'          => format_date(now),
          'start_time'          => format_time(now),
        }.merge(default_trigger_settings_for(schedule))
      end

      # Checks if a given string is in a valid time format
      def self.time_valid?(time)
        Time.parse("2016-5-1 #{time}")
        true
      rescue
        false
      end

      # canonicalize given manifest hash
      # throws errors if hash structure is invalid
      # does not throw errors when invalid types are specified
      # returns original object with downcased keys
      def self.canonicalize_and_validate(manifest_hash)
        raise TypeError unless manifest_hash.is_a?(Hash)
        manifest_hash = downcase_keys(manifest_hash)

        # check for valid key usage
        invalid_keys = manifest_hash.keys - ValidKeys
        raise ArgumentError, "Unknown trigger option(s): #{Puppet::Parameter.format_value_for_display(invalid_keys)}" unless invalid_keys.empty?

        unless ValidScheduleKeys.include?(manifest_hash['schedule'])
          raise ArgumentError, "Unknown schedule type: #{manifest_hash['schedule'].inspect}"
        end

        required = V2::EVENT_BASED_TRIGGER_MAP.value?(manifest_hash['schedule']) ? [] : ['start_time']

        required.each do |field|
          next if manifest_hash.key?(field)
          raise ArgumentError, "Must specify '#{field}' when defining a trigger"
        end

        start_time_valid = time_valid?(manifest_hash['start_time'])
        raise ArgumentError, "Invalid start_time value: #{manifest_hash['start_time']}" unless start_time_valid
        # The start_time must be canonicalized to match the format that the rest of the code expects
        manifest_hash['start_time'] = format_time(Time.parse(manifest_hash['start_time'])) unless manifest_hash['start_time'].nil?

        # specific setting rules for schedule types
        case manifest_hash['schedule']
        when 'monthly'
          if manifest_hash.key?('on')
            if manifest_hash.key?('day_of_week') || manifest_hash.key?('which_occurrence')
              raise ArgumentError, "Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger"
            end
          elsif manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week')
            raise ArgumentError, 'which_occurrence cannot be specified as an array' if manifest_hash['which_occurrence'].is_a?(Array)

            ['day_of_week', 'which_occurrence'].each do |field|
              next if manifest_hash.key?(field)
              raise ArgumentError, "#{field} must be specified when creating a monthly day-of-week based trigger"
            end
          else
            raise ArgumentError, "Don't know how to create a 'monthly' schedule with the options: #{manifest_hash.keys.sort.join(', ')}"
          end
        when 'once'
          raise ArgumentError, "Must specify 'start_date' when defining a one-time trigger" unless manifest_hash['start_date']
        end

        if manifest_hash.key?('every')
          every = begin
                    Integer(manifest_hash['every'])
                  rescue
                    nil
                  end
          raise ArgumentError, "Invalid every value: #{manifest_hash['every']}" if every.nil?
          manifest_hash['every'] = every
        end

        # day of week uses valid names (for weekly / monthly schedules)
        if manifest_hash.key?('day_of_week')
          manifest_hash['day_of_week'] = [manifest_hash['day_of_week']].flatten
          invalid_days = manifest_hash['day_of_week'] - V2::Day.names
          raise ArgumentError, "Unknown day_of_week values(s): #{invalid_days}" unless invalid_days.empty?
        end

        if manifest_hash.key?('months')
          manifest_hash['months'] = [manifest_hash['months']].flatten
          invalid_months = manifest_hash['months'] - V2::Month.indexes
          raise ArgumentError, "Unknown months values(s): #{invalid_months}" unless invalid_months.empty?
        end

        # monthly
        if manifest_hash.key?('on')
          manifest_hash['on'] = [manifest_hash['on']].flatten
          invalid_on = manifest_hash['on'] - ((1..31).to_a + ['last'])
          raise ArgumentError, "Unknown on values(s): #{invalid_on}" unless invalid_on.empty?
        end

        # monthly day of week
        if manifest_hash.key?('which_occurrence')
          # NOTE: cannot canonicalize to an array here (yet!) because more code changes required
          invalid_which_occurrence = [manifest_hash['which_occurrence']].flatten - V2::WeeksOfMonth::WEEK_OF_MONTH_CONST_MAP.keys
          raise ArgumentError, "Unknown which_occurrence values(s): #{invalid_which_occurrence}" unless invalid_which_occurrence.empty?
        end

        # duration set with / without interval
        if manifest_hash['minutes_duration']
          duration = Integer(manifest_hash['minutes_duration'])
          # defaults to -1 when unspecified
          interval = Integer(manifest_hash['minutes_interval'] || -1)
          if duration != 0 && duration <= interval
            raise ArgumentError, 'minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0'
          end
        end

        # interval set with / without duration
        if manifest_hash['minutes_interval']
          interval = Integer(manifest_hash['minutes_interval'])
          # interval < 0
          if interval.negative?
            raise ArgumentError, 'minutes_interval must be an integer greater or equal to 0'
          end

          # defaults to a day when unspecified
          duration = Integer(manifest_hash['minutes_duration'] || 1440)

          if interval.positive? && interval >= duration
            raise ArgumentError, 'minutes_interval cannot be set without minutes_duration also being set to a number greater than 0'
          end
        end
        manifest_hash['minutes_interval'] = interval if interval
        manifest_hash['minutes_duration'] = duration if duration

        if manifest_hash['start_date']
          start_date = Time.parse(manifest_hash['start_date'] + ' 00:00')
          raise ArgumentError, "start_date must be on or after #{format_date(MINIMUM_TRIGGER_DATE)}" unless start_date >= MINIMUM_TRIGGER_DATE
          manifest_hash['start_date'] = format_date(start_date)
        end

        if manifest_hash['user_id']
          raise 'user_id can only be verified on a Windows Operating System' unless Puppet.features.microsoft_windows?
          # If the user specifies undef in the manifest, coerce that into an empty string;
          # This is what scheduled tasks expects to receive for 'all users'
          user_id = (manifest_hash['user_id'] == :undef) ? '' : manifest_hash['user_id']
          # If the user cannot be resolved, the task will fail to save with a vague error
          raise ArgumentError, "Invalid user, specified user must exist: #{user_id}" unless Puppet::Util::Windows::SID.name_to_sid(user_id)
          # To keep the internal comparison consistent but human readable, convert from
          # the user id specified in the manifest to the canonical representation of that
          # account's SID on the system. If the specified user_id is null/empty, leave it
          # that way so the task runs whenever _any_ user logs on.
          user_id = Puppet::Util::Windows::SID.sid_to_name(Puppet::Util::Windows::SID.name_to_sid(user_id)) unless user_id == ''
          manifest_hash['user_id'] = user_id
        end

        manifest_hash
      end

      # converts all keys to lowercase
      def self.downcase_keys(hash)
        rekeyed = hash.map do |k, v|
          [k.is_a?(String) ? k.downcase : k, v.is_a?(Hash) ? downcase_keys(v) : v]
        end
        Hash[rekeyed]
      end

      private_class_method :downcase_keys
    end

    # Task Scheduler API V2
    class V2
      # Gets or sets the days of the week in which the task runs.
      class Day
        # V1 WEEKLY structure
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384014(v=vs.85).aspx
        # V2 IWeeklyTrigger::DaysOfWeek / IMonthlyDOWTrigger::DaysOfWeek
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381905(v=vs.85).aspx

        # The task will run on Sunday.
        TASK_SUNDAY       = 0x1

        # The task will run on Monday.
        TASK_MONDAY       = 0x2

        # The task will run on Tuesday.
        TASK_TUESDAY      = 0x4

        # The task will run on Wednesday.
        TASK_WEDNESDAY    = 0x8

        # The task will run on Thursday.
        TASK_THURSDAY     = 0x10

        # The task will run on Friday.
        TASK_FRIDAY       = 0x20

        # The task will run on Saturday.
        TASK_SATURDAY     = 0x40

        # 7 bits for 7 possible days to set
        MAX_VALUE = 0b1111111

        # Day name to HEX map
        DAY_CONST_MAP = {
          'sun'   => TASK_SUNDAY,
          'mon'   => TASK_MONDAY,
          'tues'  => TASK_TUESDAY,
          'wed'   => TASK_WEDNESDAY,
          'thurs' => TASK_THURSDAY,
          'fri'   => TASK_FRIDAY,
          'sat'   => TASK_SATURDAY,
        }.freeze

        # Returns day names
        def self.names
          @names ||= DAY_CONST_MAP.keys.freeze
        end

        # Returns day task values
        def self.values
          @values ||= DAY_CONST_MAP.values.freeze
        end

        # Converts day names to bitmask
        def self.names_to_bitmask(day_names)
          day_names = [day_names].flatten
          invalid_days = day_names - DAY_CONST_MAP.keys
          raise ArgumentError, "Days_of_week value #{invalid_days.join(', ')} is invalid. Expected sun, mon, tue, wed, thu, fri or sat." unless invalid_days.empty?

          day_names.reduce(0) { |bitmask, day| bitmask | DAY_CONST_MAP[day] }
        end

        # Converts bitmask to day names
        def self.bitmask_to_names(bitmask)
          bitmask = Integer(bitmask)
          if bitmask.negative? || bitmask > MAX_VALUE
            raise ArgumentError, "bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}"
          end

          DAY_CONST_MAP.values.each_with_object([]) do |day, names|
            names << DAY_CONST_MAP.key(day) if bitmask & day != 0
          end
        end
      end

      # Defines the day of the month the task will run.
      class Days
        # 32 bit mask, but only 31 days can be set.
        # This is contrary to the V2 IMonthlyTrigger::DaysOfMonth documentation
        # referenced below, but in testing, setting the last bit of the bit
        # mask does not set 'last' day of month as that documentation suggests.
        # Instead it results in an error. That feature will be handled instead
        # by the RunOnLastDayOfMonth property of the trigger object.
        # V2 IMonthlyTrigger::RunOnLastDayOfMonth
        # https://docs.microsoft.com/en-us/windows/win32/api/taskschd/nf-taskschd-imonthlytrigger-put_runonlastdayofmonth
        MAX_VALUE = 0b01111111111111111111111111111111

        # V1 MONTHLYDATE structure
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
        # V2 IMonthlyTrigger::DaysOfMonth
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380735(v=vs.85).aspx
        def self.indexes_to_bitmask(day_indexes)
          if day_indexes.nil? || (day_indexes.is_a?(Hash) && day_indexes.empty?)
            raise TypeError, 'Day indexes value must not be nil or an empty hash.'
          end

          integer_days = Array(day_indexes).select { |i| i.is_a?(Integer) }
          invalid_days = integer_days.reject { |i| i.between?(1, 31) }

          unless invalid_days.empty?
            raise ArgumentError, "Day indexes value #{invalid_days.join(', ')} is invalid. Integers must be in the range 1-31"
          end
          integer_days.reduce(0) { |bitmask, day_index| bitmask | 1 << day_index - 1 }
        end

        # Converts bitmask to index
        def self.bitmask_to_indexes(bitmask, run_on_last_day_of_month = nil)
          bitmask = Integer(bitmask)
          if bitmask.negative? || bitmask > MAX_VALUE
            raise ArgumentError, "bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}"
          end

          indexes = bit_index(bitmask).map { |bit_index| bit_index + 1 }

          indexes << 'last' if run_on_last_day_of_month

          indexes
        end

        # Returns bit index
        def self.bit_index(bitmask)
          (0..31).select do |bit_index|
            bit_to_check = 1 << bit_index
            # given position is set in the bitmask
            (bitmask & bit_to_check) == bit_to_check
          end
        end

        def self.last_day_of_month?(day_indexes)
          invalid_day_names = Array(day_indexes).select { |i| i.is_a?(String) && (i != 'last') }
          unless invalid_day_names.empty?
            raise ArgumentError, "Only 'last' is allowed as a day name. All other values must be integers between 1 and 31."
          end
          Array(day_indexes).include? 'last'
        end
      end

      # Gets or sets the months of the year during which the task runs.
      class Month
        # V1 MONTHLYDATE structure
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
        # V2 IMonthlyTrigger::MonthsOfYear / IMonthlyDOWTrigger::MonthsOfYear
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380736(v=vs.85).aspx

        # The task will run in January.
        TASK_JANUARY      = 0x1

        # The task will run in February.
        TASK_FEBRUARY     = 0x2

        # The task will run in March.
        TASK_MARCH        = 0x4

        # The task will run in April.
        TASK_APRIL        = 0x8

        # The task will run in May.
        TASK_MAY          = 0x10

        # The task will run in June.
        TASK_JUNE         = 0x20

        # The task will run in July.
        TASK_JULY         = 0x40

        # The task will run in August.
        TASK_AUGUST       = 0x80

        # The task will run in September.
        TASK_SEPTEMBER    = 0x100

        # The task will run in October.
        TASK_OCTOBER      = 0x200

        # The task will run in November.
        TASK_NOVEMBER     = 0x400

        # The task will run in December.
        TASK_DECEMBER     = 0x800

        # 12 bits for 12 possible months to set
        MAX_VALUE = 0b111111111111

        # Month number to HEX map
        MONTHNUM_CONST_MAP = {
          1  => TASK_JANUARY,
          2  => TASK_FEBRUARY,
          3  => TASK_MARCH,
          4  => TASK_APRIL,
          5  => TASK_MAY,
          6  => TASK_JUNE,
          7  => TASK_JULY,
          8  => TASK_AUGUST,
          9  => TASK_SEPTEMBER,
          10 => TASK_OCTOBER,
          11 => TASK_NOVEMBER,
          12 => TASK_DECEMBER,
        }.freeze

        # Returns month indexes
        def self.indexes
          @indexes ||= MONTHNUM_CONST_MAP.keys.freeze
        end

        # Converts indexes to bitmask
        def self.indexes_to_bitmask(month_indexes)
          month_indexes = [month_indexes].flatten.map do |m|
            begin
                                                Integer(m)
            rescue
              m
                                              end
          end
          invalid_months = month_indexes - MONTHNUM_CONST_MAP.keys
          raise ArgumentError, 'Month must be specified as an integer in the range 1-12' unless invalid_months.empty?

          month_indexes.reduce(0) { |bitmask, month_index| bitmask | MONTHNUM_CONST_MAP[month_index] }
        end

        # Converts bitmask to indexes
        def self.bitmask_to_indexes(bitmask)
          bitmask = Integer(bitmask)
          if bitmask.negative? || bitmask > MAX_VALUE
            raise ArgumentError, "bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}"
          end

          MONTHNUM_CONST_MAP.values.each_with_object([]) do |day, indexes|
            indexes << MONTHNUM_CONST_MAP.key(day) if bitmask & day != 0
          end
        end
      end

      # Gets or sets the weeks of the month during which the task runs.
      class WeeksOfMonth
        # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380733(v=vs.85).aspx
        # First week of the month to HEX
        FIRST = 0x01

        # Second week of the month to HEX
        SECOND  = 0x02

        # Third week of the month to HEX
        THIRD   = 0x04

        # Forth week of the month to HEX
        FOURTH  = 0x08

        # Last week of the month to HEX
        LAST    = 0x10

        # 5 bits for 5 possible weeks to set
        MAX_VALUE = 0b11111

        # Week of the month to HEX map
        WEEK_OF_MONTH_CONST_MAP = {
          'first'  => FIRST,
          'second' => SECOND,
          'third'  => THIRD,
          'fourth' => FOURTH,
          'last'   => LAST,
        }.freeze

        # Converts names to bitmask
        def self.names_to_bitmask(week_names)
          week_names = [week_names].flatten
          invalid_weeks = week_names - WEEK_OF_MONTH_CONST_MAP.keys
          raise ArgumentError, "week_names value #{invalid_weeks.join(', ')} is invalid. Expected first, second, third, fourth or last." unless invalid_weeks.empty?

          week_names.reduce(0) { |bitmask, day| bitmask | WEEK_OF_MONTH_CONST_MAP[day] }
        end

        # Converts bitmask to names
        def self.bitmask_to_names(bitmask)
          bitmask = Integer(bitmask)
          if bitmask.negative? || bitmask > MAX_VALUE
            raise ArgumentError, "bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}"
          end

          WEEK_OF_MONTH_CONST_MAP.values.each_with_object([]) do |week, names|
            names << WEEK_OF_MONTH_CONST_MAP.key(week) if bitmask & week != 0
          end
        end
      end

      # Defines the type of triggers that can be used by tasks.
      class Type
        # https://docs.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_trigger_type2
        # Triggers the task when a specific event occurs.
        TASK_TRIGGER_EVENT                 = 0

        # Triggers the task at a specific time of day.
        TASK_TRIGGER_TIME                  = 1

        # Triggers the task on a daily schedule. For example, the task starts at a specific time every day, every-other day, every third day, and so on.
        TASK_TRIGGER_DAILY                 = 2

        # Triggers the task on a weekly schedule. For example, the task starts at 8:00 AM on a specific day every week or other week.
        TASK_TRIGGER_WEEKLY                = 3

        # Triggers the task on a monthly schedule. For example, the task starts on specific days of specific months.
        TASK_TRIGGER_MONTHLY               = 4

        # Triggers the task on a monthly day-of-week schedule. For example, the task starts on a specific days of the week, weeks of the month, and months of the year.
        TASK_TRIGGER_MONTHLYDOW            = 5

        # Triggers the task when the computer goes into an idle state.
        TASK_TRIGGER_IDLE                  = 6

        # Triggers the task when the task is registered.
        TASK_TRIGGER_REGISTRATION          = 7

        # Triggers the task when the computer boots.
        TASK_TRIGGER_BOOT                  = 8

        # Triggers the task when a specific user logs on.
        TASK_TRIGGER_LOGON                 = 9

        # Triggers the task when a specific session state changes.
        TASK_TRIGGER_SESSION_STATE_CHANGE  = 11

        # Custom trigger
        TASK_TRIGGER_CUSTOM_TRIGGER_01     = 12
      end

      # https://docs.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_session_state_change_type
      class SessionStateChangeType
        # Terminal Server console connection state change. For example, when you connect to a user session on the local computer by switching users on the computer.
        TASK_CONSOLE_CONNECT      = 1

        # Terminal Server console disconnection state change. For example, when you disconnect to a user session on the local computer by switching users on the computer.
        TASK_CONSOLE_DISCONNECT   = 2

        # Terminal Server remote connection state change. For example, when a user connects to a user session by using the Remote Desktop Connection program from a remote computer.
        TASK_REMOTE_CONNECT       = 3

        # Terminal Server remote disconnection state change. For example, when a user disconnects from a user session while using the Remote Desktop Connection program from a remote computer.
        TASK_REMOTE_DISCONNECT    = 4

        # Terminal Server session locked state change. For example, this state change causes the task to run when the computer is locked.
        TASK_SESSION_LOCK         = 7

        # Terminal Server session unlocked state change. For example, this state change causes the task to run when the computer is unlocked.
        TASK_SESSION_UNLOCK       = 8
      end

      # Trigger type to day map
      SCHEDULE_BASED_TRIGGER_MAP = {
        Type::TASK_TRIGGER_DAILY      => 'daily',
        Type::TASK_TRIGGER_WEEKLY     => 'weekly',
        # NOTE: monthly uses context to determine MONTHLY or MONTHLYDOW
        Type::TASK_TRIGGER_MONTHLY    => 'monthly',
        Type::TASK_TRIGGER_MONTHLYDOW => 'monthly',
        Type::TASK_TRIGGER_TIME       => 'once',
      }.freeze

      # Event based trigger map
      EVENT_BASED_TRIGGER_MAP = {
        Type::TASK_TRIGGER_BOOT                 => 'boot',
        Type::TASK_TRIGGER_LOGON                => 'logon',
        # The triggers below are not yet supported.
        # Type::TASK_TRIGGER_EVENT                => 'event',
        # Type::TASK_TRIGGER_IDLE                 => 'idle',
        # Type::TASK_TRIGGER_REGISTRATION         => 'task_registered',
        # Type::TASK_TRIGGER_SESSION_STATE_CHANGE => 'session_state_change',
      }.freeze

      # Type manifest map
      TYPE_MANIFEST_MAP = SCHEDULE_BASED_TRIGGER_MAP.merge(EVENT_BASED_TRIGGER_MAP).freeze

      # Returns a type based on a manifest hash
      def self.type_from_manifest_hash(manifest_hash)
        # monthly schedule defaults to TASK_TRIGGER_MONTHLY unless...
        if manifest_hash['schedule'] == 'monthly' &&
           (manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week'))
          return Type::TASK_TRIGGER_MONTHLYDOW
        end

        TYPE_MANIFEST_MAP.key(manifest_hash['schedule'])
      end

      # Converts trigger to manifest hash
      def self.to_manifest_hash(i_trigger)
        if TYPE_MANIFEST_MAP[i_trigger.Type].nil?
          raise ArgumentError, _('Unknown trigger type %{type}') % { type: i_trigger.ole_type.to_s }
        end

        # StartBoundary and EndBoundary may be empty strings per V2 API
        start_boundary = Trigger.iso8601_datetime_to_local(i_trigger.StartBoundary)
        _end_boundary = Trigger.iso8601_datetime_to_local(i_trigger.EndBoundary)

        manifest_hash = {
          'start_date'       => start_boundary ? Manifest.format_date(start_boundary) : '',
          'start_time'       => start_boundary ? Manifest.format_time(start_boundary) : '',
          'enabled'          => i_trigger.Enabled,
          'minutes_interval' => Duration.to_minutes(i_trigger.Repetition.Interval) || 0,
          'minutes_duration' => Duration.to_minutes(i_trigger.Repetition.Duration) || 0,
        }

        case i_trigger.Type
        when Type::TASK_TRIGGER_TIME
          manifest_hash['schedule'] = 'once'
        when Type::TASK_TRIGGER_DAILY
          manifest_hash['schedule'] = 'daily'
          manifest_hash['every'] = i_trigger.DaysInterval
        when Type::TASK_TRIGGER_WEEKLY
          manifest_hash.merge!('schedule'    => 'weekly',
                               'every'       => i_trigger.WeeksInterval,
                               'day_of_week' => Day.bitmask_to_names(i_trigger.DaysOfWeek))
        when Type::TASK_TRIGGER_MONTHLY
          manifest_hash.merge!('schedule' => 'monthly',
                               'months'   => Month.bitmask_to_indexes(i_trigger.MonthsOfYear),
                               'on'       => Days.bitmask_to_indexes(i_trigger.DaysOfMonth, i_trigger.RunOnLastDayOfMonth))
        when Type::TASK_TRIGGER_MONTHLYDOW
          occurrences = V2::WeeksOfMonth.bitmask_to_names(i_trigger.WeeksOfMonth)
          manifest_hash.merge!('schedule'         => 'monthly',
                               'months'           => Month.bitmask_to_indexes(i_trigger.MonthsOfYear),
                               # HACK: choose only the first week selected when converting - this LOSES information
                               'which_occurrence' => occurrences.first || '',
                               'day_of_week'      => Day.bitmask_to_names(i_trigger.DaysOfWeek))
          # MODULES-10101: We will need to evaluate whether the value 'last' has been applied to the WeekOfMonth
          # parameter by inspecting the value of Trigger::RunOnLastWeekOfMonth. See JIRA ticket for more details.
          manifest_hash['which_occurrence'] = 'last' if i_trigger.RunOnLastWeekOfMonth
        when Type::TASK_TRIGGER_BOOT
          manifest_hash['schedule'] = 'boot'
        when Type::TASK_TRIGGER_LOGON
          # Resolve the UserID unless it is an empty string, which represents all users.
          user_id = (i_trigger.UserId == '') ? '' : Puppet::Util::Windows::SID.sid_to_name(Puppet::Util::Windows::SID.name_to_sid(i_trigger.UserId))
          manifest_hash['schedule'] = 'logon'
          manifest_hash['user_id'] = user_id
        end

        manifest_hash
      end

      # Adds trigger to definition
      def self.append_trigger(definition, manifest_hash)
        manifest_hash = Trigger::Manifest.canonicalize_and_validate(manifest_hash)
        # create appropriate i_trigger based on 'schedule'
        i_trigger = definition.Triggers.Create(type_from_manifest_hash(manifest_hash))

        # Values for all Trigger Types
        if manifest_hash['minutes_interval']
          minutes_interval = manifest_hash['minutes_interval']
          if minutes_interval.positive?
            i_trigger.Repetition.Interval = "PT#{minutes_interval}M"
            # one day in minutes
            i_trigger.Repetition.Duration = 'PT1440M' unless manifest_hash.key?('minutes_duration')
          end
        end

        if manifest_hash['minutes_duration']
          minutes_duration = manifest_hash['minutes_duration']
          i_trigger.Repetition.Duration = "PT#{minutes_duration}M" unless minutes_duration.zero?
        end

        # manifests specify datetime in the local timezone, ITrigger accepts ISO8601
        # when start_date is null or missing, Time.parse returns today
        datetime_string = "#{manifest_hash['start_date']} #{manifest_hash['start_time']}"
        # Time.parse always assumes local time
        # If `disable_time_zone_synchronization` has been set to true then the timezone is removed from the start time
        unless datetime_string.strip.empty?
          start = if manifest_hash['disable_time_zone_synchronization'] && manifest_hash['disable_time_zone_synchronization'] == true
                    Time.parse(datetime_string).iso8601.gsub(%r{Z|(\+..\:..$)|(\-..\:..$)}, '')
                  else
                    Time.parse(datetime_string).iso8601
                  end
          i_trigger.StartBoundary = start
        end

        # ITrigger specific settings
        case i_trigger.Type
        when Type::TASK_TRIGGER_DAILY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
          i_trigger.DaysInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_WEEKLY
          days_of_week = manifest_hash['day_of_week'] || Day.names
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
          i_trigger.DaysOfWeek = Day.names_to_bitmask(days_of_week)
          i_trigger.WeeksInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_MONTHLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
          i_trigger.RunOnLastDayOfMonth = Days.last_day_of_month?(manifest_hash['on'])
          i_trigger.DaysOfMonth = Days.indexes_to_bitmask(manifest_hash['on'])
          i_trigger.MonthsOfYear = Month.indexes_to_bitmask(manifest_hash['months'] || Month.indexes)

        when Type::TASK_TRIGGER_MONTHLYDOW
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
          i_trigger.DaysOfWeek = Day.names_to_bitmask(manifest_hash['day_of_week'])
          i_trigger.MonthsOfYear = Month.indexes_to_bitmask(manifest_hash['months'] || Month.indexes)
          # HACK: convert V1 week value to names, then back to V2 bitmask
          i_trigger.WeeksOfMonth = WeeksOfMonth.names_to_bitmask(manifest_hash['which_occurrence'])

        when Type::TASK_TRIGGER_LOGON
          i_trigger.UserId = manifest_hash['user_id']
        end

        nil
      end
    end
  end
end
