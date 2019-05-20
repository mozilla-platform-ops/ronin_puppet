require 'time'

# @api private
module PuppetX
module PuppetLabs
module ScheduledTask

module Trigger
  class Duration
    # From https://msdn.microsoft.com/en-us/library/windows/desktop/aa381850(v=vs.85).aspx
    # https://en.wikipedia.org/wiki/ISO_8601#Durations
    #
    # The format for this string is PnYnMnDTnHnMnS, where nY is the number of years, nM is the number of months,
    # nD is the number of days, 'T' is the date/time separator, nH is the number of hours, nM is the number of minutes,
    # and nS is the number of seconds (for example, PT5M specifies 5 minutes and P1M4DT2H5M specifies one month,
    # four days, two hours, and five minutes)
    def self.to_hash(duration)
      regex = /^P((?'year'\d+)Y)?((?'month'\d+)M)?((?'day'\d+)D)?(T((?'hour'\d+)H)?((?'minute'\d+)M)?((?'second'\d+)S)?)?$/

      matches = regex.match(duration)
      return nil if matches.nil?

      {
        :year => matches['year'],
        :month => matches['month'],
        :day => matches['day'],
        :minute => matches['minute'],
        :hour => matches['hour'],
        :second => matches['second'],
      }
    end

    def self.hash_to_seconds(value)
      return 0 if value.nil?
      time = 0
      # Note - the Year and Month calculations are approximate
      time = time + value[:year].to_i   * (365.2422 * 24 * 60**2)      unless value[:year].nil?
      time = time + value[:month].to_i  * (365.2422 * 2 * 60**2)       unless value[:month].nil?
      time = time + value[:day].to_i    * 24 * 60**2                   unless value[:day].nil?
      time = time + value[:hour].to_i   * 60**2                        unless value[:hour].nil?
      time = time + value[:minute].to_i * 60                           unless value[:minute].nil?
      time = time + value[:second].to_i                                unless value[:second].nil?

      time.to_i
    end

    def self.to_minutes(value)
      return 0 if value.nil?
      return 0 unless value.is_a?(String)
      return 0 if value.empty?

      duration = hash_to_seconds(to_hash(value))

      duration / 60
    end
  end

  def iso8601_datetime_to_local(value)
    return nil if value.nil?
    raise ArgumentError.new('value must be a String') unless value.is_a?(String)
    return nil if value.empty?

    # defaults to parsing as local with no timezone passed
    Time.parse(value).getlocal
  end
  module_function :iso8601_datetime_to_local

  class Manifest
    ValidKeys = [
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
     ].freeze

     ValidScheduleKeys = [
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

    def self.format_date(time)
      time.strftime('%Y-%-m-%-d')
    end

    def self.format_time(time)
      # equivalent to the ISO8601 %H:%M
      time.strftime('%R')
    end

    def self.default_trigger_settings_for(schedule = 'once')
      case schedule
      when 'once'
        {
          'schedule' => 'once',
        }
      when 'daily'
        {
          'schedule' => 'daily',
          'every'    => 1 ,
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
          'days'     => 0
        }
      end
    end

    def self.default_trigger_for(schedule = 'once')
      now = Time.now
      type_hash =
      {
        'enabled'             => true,
        'minutes_interval'    => 0,
        'minutes_duration'    => 0,
        'start_date'          => format_date(now),
        'start_time'          => format_time(now),
      }.merge(default_trigger_settings_for(schedule))
    end

    # canonicalize given manifest hash
    # throws errors if hash structure is invalid
    # does not throw errors when invalid types are specified
    # @returns original object with downcased keys
    def self.canonicalize_and_validate(manifest_hash)
      raise TypeError unless manifest_hash.is_a?(Hash)
      manifest_hash = downcase_keys(manifest_hash)

      # check for valid key usage
      invalid_keys = manifest_hash.keys - ValidKeys
      raise ArgumentError.new("Unknown trigger option(s): #{Puppet::Parameter.format_value_for_display(invalid_keys)}") unless invalid_keys.empty?

      if !ValidScheduleKeys.include?(manifest_hash['schedule'])
        raise ArgumentError.new("Unknown schedule type: #{manifest_hash["schedule"].inspect}")
      end

      required = V2::EVENT_BASED_TRIGGER_MAP.value?(manifest_hash['schedule']) ? [] : %w{start_time}

      required.each do |field|
        next if manifest_hash.key?(field)
        raise ArgumentError.new("Must specify '#{field}' when defining a trigger")
      end

      start_time_valid = begin Time.parse("2016-5-1 #{manifest_hash['start_time']}"); true rescue false; end
      raise ArgumentError.new("Invalid start_time value: #{manifest_hash['start_time']}") unless start_time_valid
      # The start_time must be canonicalized to match the format that the rest of the code expects
      manifest_hash['start_time'] = format_time(Time.parse(manifest_hash['start_time'])) unless manifest_hash['start_time'].nil?

      # specific setting rules for schedule types
      case manifest_hash['schedule']
      when 'monthly'
        if manifest_hash.key?('on')
          if manifest_hash.key?('day_of_week') || manifest_hash.key?('which_occurrence')
            raise ArgumentError.new("Neither 'day_of_week' nor 'which_occurrence' can be specified when creating a monthly date-based trigger")
          end
        elsif manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week')
          raise ArgumentError.new('which_occurrence cannot be specified as an array') if manifest_hash['which_occurrence'].is_a?(Array)

          %w{day_of_week which_occurrence}.each do |field|
            next if manifest_hash.key?(field)
            raise ArgumentError.new("#{field} must be specified when creating a monthly day-of-week based trigger")
          end
        else
          raise ArgumentError.new("Don't know how to create a 'monthly' schedule with the options: #{manifest_hash.keys.sort.join(', ')}")
        end
      when 'once'
        raise ArgumentError.new("Must specify 'start_date' when defining a one-time trigger") unless manifest_hash['start_date']
      end

      if manifest_hash.key?('every')
        every = begin Integer(manifest_hash['every']) rescue nil end
        raise ArgumentError.new("Invalid every value: #{manifest_hash['every']}") if every.nil?
        manifest_hash['every'] = every
      end

      # day of week uses valid names (for weekly / monthly schedules)
      if manifest_hash.key?('day_of_week')
        manifest_hash['day_of_week'] = [manifest_hash['day_of_week']].flatten
        invalid_days = manifest_hash['day_of_week'] - V2::Day.names
        raise ArgumentError.new("Unknown day_of_week values(s): #{invalid_days}") unless invalid_days.empty?
      end

      if manifest_hash.key?('months')
        manifest_hash['months'] = [manifest_hash['months']].flatten
        invalid_months = manifest_hash['months'] - V2::Month.indexes
        raise ArgumentError.new("Unknown months values(s): #{invalid_months}") unless invalid_months.empty?
      end

      # monthly
      if manifest_hash.key?('on')
        manifest_hash['on'] = [manifest_hash['on']].flatten
        invalid_on = manifest_hash['on'] - ((1..31).to_a + ['last'])
        raise ArgumentError.new("Unknown on values(s): #{invalid_on}") unless invalid_on.empty?
      end

      # monthly day of week
      if manifest_hash.key?('which_occurrence')
        # NOTE: cannot canonicalize to an array here (yet!) because more code changes required
        invalid_which_occurrence = [manifest_hash['which_occurrence']].flatten - V2::WeeksOfMonth::WEEK_OF_MONTH_CONST_MAP.keys
        raise ArgumentError.new("Unknown which_occurrence values(s): #{invalid_which_occurrence}") unless invalid_which_occurrence.empty?
      end

      # duration set with / without interval
      if manifest_hash['minutes_duration']
        duration = Integer(manifest_hash['minutes_duration'])
        # defaults to -1 when unspecified
        interval = Integer(manifest_hash['minutes_interval'] || -1)
        if duration != 0 && duration <= interval
          raise ArgumentError.new('minutes_duration must be an integer greater than minutes_interval and equal to or greater than 0')
        end
      end

      # interval set with / without duration
      if manifest_hash['minutes_interval']
        interval = Integer(manifest_hash['minutes_interval'])
        # interval < 0
        if interval < 0
          raise ArgumentError.new('minutes_interval must be an integer greater or equal to 0')
        end

        # defaults to a day when unspecified
        duration = Integer(manifest_hash['minutes_duration'] || 1440)

        if interval > 0 && interval >= duration
          raise ArgumentError.new('minutes_interval cannot be set without minutes_duration also being set to a number greater than 0')
        end
      end
      manifest_hash['minutes_interval'] = interval if interval
      manifest_hash['minutes_duration'] = duration if duration

      if manifest_hash['start_date']
        start_date = Time.parse(manifest_hash['start_date'] + ' 00:00')
        raise ArgumentError.new("start_date must be on or after #{format_date(MINIMUM_TRIGGER_DATE)}") unless start_date >= MINIMUM_TRIGGER_DATE
        manifest_hash['start_date'] = format_date(start_date)
      end

      if manifest_hash['user_id']
        raise RuntimeError.new('user_id can only be verified on a Windows Operating System') unless Puppet.features.microsoft_windows?
        # If the user specifies undef in the manifest, coerce that into an empty string;
        # This is what scheduled tasks expects to receive for 'all users'
        user_id = manifest_hash['user_id'] == :undef ? '' : manifest_hash['user_id']
        # If the user cannot be resolved, the task will fail to save with a vague error
        raise ArgumentError.new("Invalid user, specified user must exist: #{user_id}") unless Puppet::Util::Windows::SID.name_to_sid(user_id)
        # To keep the internal comparison consistent but human readable, convert from
        # the user id specified in the manifest to the canonical representation of that
        # account's SID on the system. If the specified user_id is null/empty, leave it
        # that way so the task runs whenever _any_ user logs on.
        user_id = Puppet::Util::Windows::SID.sid_to_name(Puppet::Util::Windows::SID.name_to_sid(user_id)) unless user_id == ''
        manifest_hash['user_id'] = user_id
      end

      manifest_hash
    end

    private

    # converts all keys to lowercase
    def self.downcase_keys(hash)
      rekeyed = hash.map do |k, v|
        [k.is_a?(String) ? k.downcase : k, v.is_a?(Hash) ? downcase_keys(v) : v]
      end
      Hash[ rekeyed ]
    end
  end

  class V2
  class Day
    # V1 WEEKLY structure
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384014(v=vs.85).aspx
    # V2 IWeeklyTrigger::DaysOfWeek / IMonthlyDOWTrigger::DaysOfWeek
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381905(v=vs.85).aspx
    TASK_SUNDAY       = 0x1
    TASK_MONDAY       = 0x2
    TASK_TUESDAY      = 0x4
    TASK_WEDNESDAY    = 0x8
    TASK_THURSDAY     = 0x10
    TASK_FRIDAY       = 0x20
    TASK_SATURDAY     = 0x40

    # 7 bits for 7 possible days to set
    MAX_VALUE = 0b1111111

    DAY_CONST_MAP = {
      'sun'   => TASK_SUNDAY,
      'mon'   => TASK_MONDAY,
      'tues'  => TASK_TUESDAY,
      'wed'   => TASK_WEDNESDAY,
      'thurs' => TASK_THURSDAY,
      'fri'   => TASK_FRIDAY,
      'sat'   => TASK_SATURDAY,
    }.freeze

    def self.names
      @names ||= DAY_CONST_MAP.keys.freeze
    end

    def self.values
      @values ||= DAY_CONST_MAP.values.freeze
    end

    def self.names_to_bitmask(day_names)
      day_names = [day_names].flatten
      invalid_days = day_names - DAY_CONST_MAP.keys
      raise ArgumentError.new("Days_of_week value #{invalid_days.join(', ')} is invalid. Expected sun, mon, tue, wed, thu, fri or sat.") unless invalid_days.empty?

      day_names.inject(0) { |bitmask, day| bitmask |= DAY_CONST_MAP[day] }
    end

    def self.bitmask_to_names(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > MAX_VALUE)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}")
      end

      DAY_CONST_MAP.values.each_with_object([]) do |day, names|
        names << DAY_CONST_MAP.key(day) if bitmask & day != 0
      end
    end
  end
  end

  class V2
  class Days
    # 32 bits for 31 possible days to set + value 'last'
    MAX_VALUE = 0b11111111111111111111111111111111

    # V1 MONTHLYDATE structure
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
    # V2 IMonthlyTrigger::DaysOfMonth
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380735(v=vs.85).aspx
    def self.indexes_to_bitmask(day_indexes)
      day_indexes = [day_indexes].flatten.map do |m|
        # The special "day" of 'last' is represented by day "number"
        # 32. 'last' has the special meaning of "the last day of the
        # month", no matter how many days there are in the month.
        # raises if unable to convert
        m.is_a?(String) && m.casecmp('last') == 0 ? 32 : Integer(m)
      end

      invalid_days = day_indexes.find_all { |i| !i.between?(1, 32) }
      if !invalid_days.empty?
        raise ArgumentError.new("Day indexes value #{invalid_days.join(', ')} is invalid. Integers must be in the range 1-31, or 'last'")
      end

      day_indexes.inject(0) { |bitmask, day_index| bitmask |= 1 << day_index - 1 }
    end

    def self.bitmask_to_indexes(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > MAX_VALUE)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}")
      end

      (0..31).select do |bit_index|
        bit_to_check = 1 << bit_index
        # given position is set in the bitmask
        (bitmask & bit_to_check) == bit_to_check
      end.map do |bit_index|
        # Day 32 has the special meaning of "the last day of the
        # month", no matter how many days there are in the month.
        bit_index == 31 ? 'last' : bit_index + 1
      end
    end
  end
  end

  class V2
  class Month
    # V1 MONTHLYDATE structure
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381918(v=vs.85).aspx
    # V2 IMonthlyTrigger::MonthsOfYear / IMonthlyDOWTrigger::MonthsOfYear
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380736(v=vs.85).aspx
    TASK_JANUARY      = 0x1
    TASK_FEBRUARY     = 0x2
    TASK_MARCH        = 0x4
    TASK_APRIL        = 0x8
    TASK_MAY          = 0x10
    TASK_JUNE         = 0x20
    TASK_JULY         = 0x40
    TASK_AUGUST       = 0x80
    TASK_SEPTEMBER    = 0x100
    TASK_OCTOBER      = 0x200
    TASK_NOVEMBER     = 0x400
    TASK_DECEMBER     = 0x800

    # 12 bits for 12 possible months to set
    MAX_VALUE = 0b111111111111

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

    def self.indexes
      @indexes ||= MONTHNUM_CONST_MAP.keys.freeze
    end

    def self.indexes_to_bitmask(month_indexes)
      month_indexes = [month_indexes].flatten.map { |m| Integer(m) rescue m }
      invalid_months = month_indexes - MONTHNUM_CONST_MAP.keys
      raise ArgumentError.new('Month must be specified as an integer in the range 1-12') unless invalid_months.empty?

      month_indexes.inject(0) { |bitmask, month_index| bitmask |= MONTHNUM_CONST_MAP[month_index] }
    end

    def self.bitmask_to_indexes(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > MAX_VALUE)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}")
      end

      MONTHNUM_CONST_MAP.values.each_with_object([]) do |day, indexes|
        indexes << MONTHNUM_CONST_MAP.key(day) if bitmask & day != 0
      end
    end
  end
  end

  class V2
  class WeeksOfMonth
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa380733(v=vs.85).aspx
    FIRST   = 0x01
    SECOND  = 0x02
    THIRD   = 0x04
    FOURTH  = 0x08
    LAST    = 0x10

    # 5 bits for 5 possible weeks to set
    MAX_VALUE = 0b11111

    WEEK_OF_MONTH_CONST_MAP = {
      'first'  => FIRST,
      'second' => SECOND,
      'third'  => THIRD,
      'fourth' => FOURTH,
      'last'   => LAST,
    }.freeze

    def self.names_to_bitmask(week_names)
      week_names = [week_names].flatten
      invalid_weeks = week_names - WEEK_OF_MONTH_CONST_MAP.keys
      raise ArgumentError.new("week_names value #{invalid_weeks.join(', ')} is invalid. Expected first, second, third, fourth or last.") unless invalid_weeks.empty?

      week_names.inject(0) { |bitmask, day| bitmask |= WEEK_OF_MONTH_CONST_MAP[day] }
    end

    def self.bitmask_to_names(bitmask)
      bitmask = Integer(bitmask)
      if (bitmask < 0 || bitmask > MAX_VALUE)
        raise ArgumentError.new("bitmask must be specified as an integer from 0 to #{MAX_VALUE.to_s(10)}")
      end

      WEEK_OF_MONTH_CONST_MAP.values.each_with_object([]) do |week, names|
        names << WEEK_OF_MONTH_CONST_MAP.key(week) if bitmask & week != 0
      end
    end
  end
  end

  class V2
    class Type
      # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_trigger_type2
      TASK_TRIGGER_EVENT                 = 0
      TASK_TRIGGER_TIME                  = 1
      TASK_TRIGGER_DAILY                 = 2
      TASK_TRIGGER_WEEKLY                = 3
      TASK_TRIGGER_MONTHLY               = 4
      TASK_TRIGGER_MONTHLYDOW            = 5
      TASK_TRIGGER_IDLE                  = 6
      TASK_TRIGGER_REGISTRATION          = 7
      TASK_TRIGGER_BOOT                  = 8
      TASK_TRIGGER_LOGON                 = 9
      TASK_TRIGGER_SESSION_STATE_CHANGE  = 11
      TASK_TRIGGER_CUSTOM_TRIGGER_01     = 12
    end

    # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_session_state_change_type
    class SessionStateChangeType
      TASK_CONSOLE_CONNECT      = 1
      TASK_CONSOLE_DISCONNECT   = 2
      TASK_REMOTE_CONNECT       = 3
      TASK_REMOTE_DISCONNECT    = 4
      TASK_SESSION_LOCK         = 7
      TASK_SESSION_UNLOCK       = 8
    end

    SCHEDULE_BASED_TRIGGER_MAP = {
      Type::TASK_TRIGGER_DAILY      => 'daily',
      Type::TASK_TRIGGER_WEEKLY     => 'weekly',
      # NOTE: monthly uses context to determine MONTHLY or MONTHLYDOW
      Type::TASK_TRIGGER_MONTHLY    => 'monthly',
      Type::TASK_TRIGGER_MONTHLYDOW => 'monthly',
      Type::TASK_TRIGGER_TIME       => 'once',
    }.freeze

    EVENT_BASED_TRIGGER_MAP = {
      Type::TASK_TRIGGER_BOOT                 => 'boot',
      Type::TASK_TRIGGER_LOGON                => 'logon',
      # The triggers below are not yet supported.
      # Type::TASK_TRIGGER_EVENT                => 'event',
      # Type::TASK_TRIGGER_IDLE                 => 'idle',
      # Type::TASK_TRIGGER_REGISTRATION         => 'task_registered',
      # Type::TASK_TRIGGER_SESSION_STATE_CHANGE => 'session_state_change',
    }.freeze

    TYPE_MANIFEST_MAP = (SCHEDULE_BASED_TRIGGER_MAP.merge(EVENT_BASED_TRIGGER_MAP)).freeze

    def self.type_from_manifest_hash(manifest_hash)
      # monthly schedule defaults to TASK_TRIGGER_MONTHLY unless...
      if manifest_hash['schedule'] == 'monthly' &&
        (manifest_hash.key?('which_occurrence') || manifest_hash.key?('day_of_week'))
        return Type::TASK_TRIGGER_MONTHLYDOW
      end

      TYPE_MANIFEST_MAP.key(manifest_hash['schedule'])
    end

    def self.to_manifest_hash(iTrigger)
      if TYPE_MANIFEST_MAP[iTrigger.Type].nil?
        raise ArgumentError.new(_("Unknown trigger type %{type}") % { type: iTrigger.ole_type.to_s })
      end

      # StartBoundary and EndBoundary may be empty strings per V2 API
      start_boundary = Trigger.iso8601_datetime_to_local(iTrigger.StartBoundary)
      end_boundary = Trigger.iso8601_datetime_to_local(iTrigger.EndBoundary)

      manifest_hash = {
        'start_date'       => start_boundary ? Manifest.format_date(start_boundary) : '',
        'start_time'       => start_boundary ? Manifest.format_time(start_boundary) : '',
        'enabled'          => iTrigger.Enabled,
        'minutes_interval' => Duration.to_minutes(iTrigger.Repetition.Interval) || 0,
        'minutes_duration' => Duration.to_minutes(iTrigger.Repetition.Duration) || 0,
      }

      case iTrigger.Type
        when Type::TASK_TRIGGER_TIME
          manifest_hash['schedule'] = 'once'
        when Type::TASK_TRIGGER_DAILY
          manifest_hash.merge!({
            'schedule' => 'daily',
            'every'    => iTrigger.DaysInterval,
          })
        when Type::TASK_TRIGGER_WEEKLY
          manifest_hash.merge!({
            'schedule'    => 'weekly',
            'every'       => iTrigger.WeeksInterval,
            'day_of_week' => Day.bitmask_to_names(iTrigger.DaysOfWeek),
          })
        when Type::TASK_TRIGGER_MONTHLY
          manifest_hash.merge!({
            'schedule' => 'monthly',
            'months'   => Month.bitmask_to_indexes(iTrigger.MonthsOfYear),
            'on'       => Days.bitmask_to_indexes(iTrigger.DaysOfMonth),
          })
        when Type::TASK_TRIGGER_MONTHLYDOW
          occurrences = V2::WeeksOfMonth.bitmask_to_names(iTrigger.WeeksOfMonth)
          manifest_hash.merge!({
            'schedule' => 'monthly',
            'months'           => Month.bitmask_to_indexes(iTrigger.MonthsOfYear),
            # HACK: choose only the first week selected when converting - this LOSES information
            'which_occurrence' => occurrences.first || '',
            'day_of_week'      => Day.bitmask_to_names(iTrigger.DaysOfWeek),
          })
        when Type::TASK_TRIGGER_BOOT
          manifest_hash.merge!({
            'schedule' => 'boot'
          })
        when Type::TASK_TRIGGER_LOGON
          # Resolve the UserID unless it is an empty string, which represents all users.
          user_id = iTrigger.UserId == '' ? '' : Puppet::Util::Windows::SID.sid_to_name(Puppet::Util::Windows::SID.name_to_sid(iTrigger.UserId))
          manifest_hash.merge!({
            'schedule' => 'logon',
            'user_id'  => user_id
          })
      end

      manifest_hash
    end

    def self.append_trigger(definition, manifest_hash)
      manifest_hash = Trigger::Manifest.canonicalize_and_validate(manifest_hash)
      # create appropriate ITrigger based on 'schedule'
      iTrigger = definition.Triggers.Create(type_from_manifest_hash(manifest_hash))

      # Values for all Trigger Types
      if manifest_hash['minutes_interval']
        minutes_interval = manifest_hash['minutes_interval']
        if minutes_interval > 0
          iTrigger.Repetition.Interval = "PT#{minutes_interval}M"
          # one day in minutes
          iTrigger.Repetition.Duration = "PT1440M" unless manifest_hash.key?('minutes_duration')
        end
      end

      if manifest_hash['minutes_duration']
        minutes_duration = manifest_hash['minutes_duration']
        iTrigger.Repetition.Duration = "PT#{minutes_duration}M" unless minutes_duration.zero?
      end

      # manifests specify datetime in the local timezone, ITrigger accepts ISO8601
      # when start_date is null or missing, Time.parse returns today
      datetime_string = "#{manifest_hash['start_date']} #{manifest_hash['start_time']}"
      # Time.parse always assumes local time
      iTrigger.StartBoundary = Time.parse(datetime_string).iso8601 unless datetime_string.strip.empty?

      # ITrigger specific settings
      case iTrigger.Type
        when Type::TASK_TRIGGER_DAILY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858(v=vs.85).aspx
          iTrigger.DaysInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_WEEKLY
          days_of_week = manifest_hash['day_of_week'] || Day.names
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019(v=vs.85).aspx
          iTrigger.DaysOfWeek = Day.names_to_bitmask(days_of_week)
          iTrigger.WeeksInterval = Integer(manifest_hash['every'] || 1)

        when Type::TASK_TRIGGER_MONTHLY
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062(v=vs.85).aspx
          iTrigger.DaysOfMonth = Days.indexes_to_bitmask(manifest_hash['on'])
          iTrigger.MonthsOfYear = Month.indexes_to_bitmask(manifest_hash['months'] || Month.indexes)

        when Type::TASK_TRIGGER_MONTHLYDOW
          # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382055(v=vs.85).aspx
          iTrigger.DaysOfWeek = Day.names_to_bitmask(manifest_hash['day_of_week'])
          iTrigger.MonthsOfYear = Month.indexes_to_bitmask(manifest_hash['months'] || Month.indexes)
          # HACK: convert V1 week value to names, then back to V2 bitmask
          iTrigger.WeeksOfMonth = WeeksOfMonth.names_to_bitmask(manifest_hash['which_occurrence'])

        when Type::TASK_TRIGGER_LOGON
          iTrigger.UserId = manifest_hash['user_id']
      end

      nil
    end
  end
end
end
end
end
