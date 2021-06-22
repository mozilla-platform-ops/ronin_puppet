# frozen_string_literal: true

require 'puppet/parameter'
require_relative '../../../puppet_x/puppetlabs/scheduled_task/task'

Puppet::Type.type(:scheduled_task).provide(:win32_taskscheduler) do
  desc "This provider manages scheduled tasks on Windows.
       This is a technical preview using the newer V2 API interface but
       still editing V1 compatbile scheduled tasks."

  confine    operatingsystem: :windows

  def self.instances
    task = PuppetX::PuppetLabs::ScheduledTask::Task
    task.tasks(task::V1_COMPATIBILITY).map do |task_name|
      new(
        provider: :win32_taskscheduler,
        name: task_name,
      )
    end
  end

  def exists?
    PuppetX::PuppetLabs::ScheduledTask::Task.exists? resource[:name]
  end

  def task
    @task ||=
      PuppetX::PuppetLabs::ScheduledTask::Task.new(resource[:name], :v1_compatibility)
  end

  def enabled
    task.enabled ? :true : :false
  end

  def command
    task.application_name
  end

  def arguments
    task.parameters
  end

  def working_dir
    task.working_directory
  end

  def user
    account = task.account_information
    return 'system' if account == ''
    account
  end

  def trigger
    @triggers ||= task.triggers.compact # remove nils for unsupported trigger types
  end

  def user_insync?(current, should)
    return false unless current

    # Win32::TaskScheduler can return the 'SYSTEM' account as the
    # empty string.
    current = 'system' if current == ''

    # By comparing account SIDs we don't have to worry about case
    # sensitivity, or canonicalization of the account name.
    Puppet::Util::Windows::SID.name_to_sid(current) == Puppet::Util::Windows::SID.name_to_sid(should[0])
  end

  def trigger_insync?(current, should)
    should  = [should] unless should.is_a?(Array)
    current = [current] unless current.is_a?(Array)
    return false unless current.length == should.length

    current_in_sync = current.all? do |c|
      should.any? { |s| triggers_same?(c, s) }
    end

    should_in_sync = should.all? do |s|
      current.any? { |c| triggers_same?(c, s) }
    end

    current_in_sync && should_in_sync
  end

  def command=(value)
    task.application_name = value
  end

  def arguments=(value)
    task.parameters = value
  end

  def working_dir=(value)
    task.working_directory = value
  end

  def enabled=(value)
    task.enabled = (value == :true)
  end

  def trigger=(value)
    desired_triggers = value.is_a?(Array) ? value : [value]
    current_triggers = trigger.is_a?(Array) ? trigger : [trigger]

    extra_triggers = []
    desired_to_search = desired_triggers.dup
    current_triggers.each do |current|
      if (found = desired_to_search.find { |desired| triggers_same?(current, desired) })
        desired_to_search.delete(found)
      else
        extra_triggers << current['index']
      end
    end

    needed_triggers = []
    current_to_search = current_triggers.dup
    desired_triggers.each do |desired|
      if (found = current_to_search.find { |current| triggers_same?(current, desired) })
        current_to_search.delete(found)
      else
        needed_triggers << desired
      end
    end

    extra_triggers.reverse_each do |index|
      task.delete_trigger(index)
    end

    needed_triggers.each do |trigger_hash|
      task.append_trigger(trigger_hash)
    end
  end

  def user=(value)
    raise("Invalid user: #{value}") unless Puppet::Util::Windows::SID.name_to_sid(value)

    if !value.to_s.casecmp('system').zero?
      task.set_account_information(value, resource[:password])
    else
      # Win32::TaskScheduler treats a nil/empty username & password as
      # requesting the SYSTEM account.
      task.set_account_information(nil, nil)
    end
  end

  def create
    @triggers = nil
    @task = PuppetX::PuppetLabs::ScheduledTask::Task.new(resource[:name], :v1_compatibility)
    self.command = resource[:command]

    [:arguments, :working_dir, :enabled, :trigger, :user].each do |prop|
      send("#{prop}=", resource[prop]) if resource[prop]
    end
  end

  def destroy
    PuppetX::PuppetLabs::ScheduledTask::Task.delete(resource[:name])
  end

  def flush
    return if resource[:ensure] == :absent
    raise('Parameter command is required.') unless resource[:command]
    # HACK: even though the user may actually be insync?, for task changes to
    # fully propagate, it is necessary to explicitly set the user for the task,
    # even when it is SYSTEM (and has a nil password)
    # this is a Windows security feature with the v1 COM APIs that prevent
    # arbitrary reassignment of a task scheduler command to run as SYSTEM
    # without the authorization to do so
    self.user = resource[:user]
    task.save
    @task = nil
  end

  def triggers_same?(current_trigger, desired_trigger)
    return false if current_trigger.key?('enabled') && !current_trigger['enabled']
    # Canonicalizing the desired hash ensures it is in a matching state with what we convert from on-disk
    desired = PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.canonicalize_and_validate(desired_trigger)
    # This method ensures that current_trigger:
    # - includes all of the key-value pairs from desired
    # - that those key value pairs are exactly matched
    # - does not preclude current_trigger from having _more_ keys than the desired trigger.
    # It will return false if any pair is missing or the values do not match.
    current_trigger.merge(desired) == current_trigger
  end

  def validate_trigger(value)
    [value].flatten.each do |t|
      ['index', 'enabled'].each do |key|
        if t.key?(key)
          raise "'#{key}' is read-only on scheduled_task triggers and should be removed ('#{key}' is usually provided in puppet resource scheduled_task)."
        end
      end
      PuppetX::PuppetLabs::ScheduledTask::Trigger::Manifest.canonicalize_and_validate(t)
    end

    true
  end

  def validate_name
    return unless @resource[:name].include?('\\')

    raise Puppet::ResourceError, "#{@resource[:name]} specifies a path including subfolders which are not supported by the version of the Task Scheduler API used by this provider."\
                                 'Use the taskscheduler_api2 provider instead.'
  end
end
