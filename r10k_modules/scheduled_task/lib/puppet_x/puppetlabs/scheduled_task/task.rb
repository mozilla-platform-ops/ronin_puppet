# This class is used to manage tasks using the Task Scheduler V2 API
#
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa383600(v=vs.85).aspx
#
require_relative './error'
require_relative './trigger'

module PuppetX
module PuppetLabs
module ScheduledTask

class Task
  # The name of the root folder for tasks
  ROOT_FOLDER = '\\'.freeze

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_enum_flags
  class TASK_ENUM_FLAGS
    TASK_ENUM_HIDDEN  = 0x1
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_action_type
  class TASK_ACTION_TYPE
    TASK_ACTION_EXEC          = 0
    TASK_ACTION_COM_HANDLER   = 5
    TASK_ACTION_SEND_EMAIL    = 6
    TASK_ACTION_SHOW_MESSAGE  = 7
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_compatibility
  # Win7/2008 R2                       = 3
  # Win8/Server 2012 R2 or Server 2016 = 4
  # Windows 10                         = 5 / 6
  class TASK_COMPATIBILITY
    TASK_COMPATIBILITY_AT     = 0
    TASK_COMPATIBILITY_V1     = 1
    TASK_COMPATIBILITY_V2     = 2
    TASK_COMPATIBILITY_V2_1   = 3
    TASK_COMPATIBILITY_V2_2   = 4
    TASK_COMPATIBILITY_V2_3   = 5
    TASK_COMPATIBILITY_V2_4   = 6
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_creation
  class TASK_CREATION
    TASK_VALIDATE_ONLY                 = 0x1
    TASK_CREATE                        = 0x2
    TASK_UPDATE                        = 0x4
    # ( TASK_CREATE | TASK_UPDATE )
    TASK_CREATE_OR_UPDATE              = 0x6
    TASK_DISABLE                       = 0x8
    TASK_DONT_ADD_PRINCIPAL_ACE        = 0x10
    TASK_IGNORE_REGISTRATION_TRIGGERS  = 0x20
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_logon_type
  class TASK_LOGON_TYPE
    TASK_LOGON_NONE                           = 0
    TASK_LOGON_PASSWORD                       = 1
    TASK_LOGON_S4U                            = 2
    TASK_LOGON_INTERACTIVE_TOKEN              = 3
    TASK_LOGON_GROUP                          = 4
    TASK_LOGON_SERVICE_ACCOUNT                = 5
    TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD  = 6
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_run_flags
  class TASK_RUN_FLAGS
    TASK_RUN_NO_FLAGS             = 0
    TASK_RUN_AS_SELF              = 0x1
    TASK_RUN_IGNORE_CONSTRAINTS   = 0x2
    TASK_RUN_USE_SESSION_ID       = 0x4
    TASK_RUN_USER_SID             = 0x8
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_runlevel
  class TASK_RUNLEVEL_TYPE
    TASK_RUNLEVEL_LUA     = 0
    TASK_RUNLEVEL_HIGHEST = 1
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_processtokensid
  class TASK_PROCESSTOKENSID_TYPE
    TASK_PROCESSTOKENSID_NONE           = 0
    TASK_PROCESSTOKENSID_UNRESTRICTED   = 1
    TASK_PROCESSTOKENSID_DEFAULT        = 2
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_state
  class TASK_STATE
    TASK_STATE_UNKNOWN    = 0
    TASK_STATE_DISABLED   = 1
    TASK_STATE_QUEUED     = 2
    TASK_STATE_READY      = 3
    TASK_STATE_RUNNING    = 4
  end

  # https://docs.microsoft.com/en-us/windows/desktop/api/taskschd/ne-taskschd-_task_instances_policy
  class TASK_INSTANCES_POLICY
    TASK_INSTANCES_PARALLEL       = 0
    TASK_INSTANCES_QUEUE          = 1
    TASK_INSTANCES_IGNORE_NEW     = 2
    TASK_INSTANCES_STOP_EXISTING  = 3
  end

  public
  # Returns a new TaskScheduler object.
  # An existing task named task_name will be returned if one exists,
  # otherwise a new task is created by that name (but not yet saved to the system).
  #
  def initialize(task_name, compatibility_level = nil)
    raise TypeError unless task_name.is_a?(String)

    @full_task_path = ROOT_FOLDER + task_name
    # definition populated when task exists, otherwise new
    @task, @definition = self.class.task(@full_task_path)
    task_userid = @definition.Principal.UserId || ''

    if compatibility_level == :v1_compatibility
      self.compatibility = TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1
    end

    set_account_information(task_userid,nil)
  end

  V1_COMPATIBILITY = [
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_AT,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1
  ].freeze

  V2_COMPATIBILITY = [
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2_4,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2_3,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2_2,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2_1,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V2,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_AT,
    TASK_COMPATIBILITY::TASK_COMPATIBILITY_V1
  ].freeze

  # Returns an array of scheduled task names.
  #
  def self.tasks(compatibility = V2_COMPATIBILITY)
    enum_task_names(ROOT_FOLDER,
      include_child_folders: false,
      include_compatibility: compatibility).map do |item|
        task_name_from_task_path(item)
    end
  end

  RESERVED_FOR_FUTURE_USE = 0

  # Returns an array of scheduled task names.
  # By default EVERYTHING is enumerated
  # option hash
  #    include_child_folders: recurses into child folders for tasks. Default true
  #    include_compatibility: Only include tasks which have any of the specified compatibility levels. Default empty array (everything is permitted)
  #
  def self.enum_task_names(folder_path = ROOT_FOLDER, enum_options = {})
    raise TypeError unless folder_path.is_a?(String)

    options = {
      :include_child_folders => true,
      :include_compatibility => [],
    }.merge(enum_options)

    array = []

    task_folder = task_service.GetFolder(folder_path)
    filter_compatibility = !options[:include_compatibility].empty?
    task_folder.GetTasks(TASK_ENUM_FLAGS::TASK_ENUM_HIDDEN).each do |task|
      next if filter_compatibility && !options[:include_compatibility].include?(task.Definition.Settings.Compatibility)
      array << task.Path
    end
    return array unless options[:include_child_folders]

    task_folder.GetFolders(RESERVED_FOR_FUTURE_USE).each do |child_folder|
      array += enum_task_names(child_folder.Path, options)
    end

    array
  end

  # Returns whether or not the scheduled task exists.
  def self.exists?(job_name)
    # task name comparison is case insensitive
    tasks.any? { |name| name.casecmp(job_name) == 0 }
  end

  # Delete the specified task name.
  #
  def self.delete(task_name)
    task_path = ROOT_FOLDER + task_name
    task_folder = task_service.GetFolder(folder_path_from_task_path(task_path))
    task_folder.DeleteTask(task_name_from_task_path(task_path), 0)
  end

  # Creates or Updates an existing task with the supplied task definition
  # Tasks must be saved before they can be activated.
  #
  # The .job file itself is typically stored in the C:\WINDOWS\Tasks folder.
  def save
    task_path = @task ? @task.Path : @full_task_path

    task_folder = self.class.task_service.GetFolder(self.class.folder_path_from_task_path(task_path))
    task_user = nil
    task_password = nil

    case @definition.Principal.LogonType
      when TASK_LOGON_TYPE::TASK_LOGON_PASSWORD,
        TASK_LOGON_TYPE::TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD
        task_user = @definition.Principal.UserId
        task_password = @task_password
    end

    saved = task_folder.RegisterTaskDefinition(
      self.class.task_name_from_task_path(task_path),
      @definition,
      TASK_CREATION::TASK_CREATE_OR_UPDATE,
      task_user, task_password, @definition.Principal.LogonType)

    @task ||= saved
  end

  # Sets the +user+ and +password+ for the given task. If the user and
  # password are set properly then true is returned.
  #
  # In some cases the job may be created, but the account information was
  # bad. In this case the task is created but a warning is generated and
  # false is returned.
  #
  # Note that if intending to use SYSTEM, specify an empty user and nil password
  #
  # This must be done prior to the 1st save() call for the task to be
  # properly registered and visible through the MMC snap-in / schtasks.exe
  #
  def set_account_information(user, password)
    @task_password = password

    if (user.nil? || user == "")
      # Setup for the local system account
      @definition.Principal.UserId = 'SYSTEM'
      @definition.Principal.LogonType = TASK_LOGON_TYPE::TASK_LOGON_SERVICE_ACCOUNT
      @definition.Principal.RunLevel = TASK_RUNLEVEL_TYPE::TASK_RUNLEVEL_HIGHEST
    else
      @definition.Principal.UserId = user
      @definition.Principal.LogonType = TASK_LOGON_TYPE::TASK_LOGON_PASSWORD
      @definition.Principal.RunLevel = TASK_RUNLEVEL_TYPE::TASK_RUNLEVEL_HIGHEST
    end

    true
  end

  # Returns the user associated with the task or nil if no user has yet
  # been associated with the task.
  #
  def account_information
    principal = @definition.Principal
    principal.nil? ? nil : principal.UserId
  end

  # Returns the name of the application associated with the task.
  #
  def application_name
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.Path
  end

  # Sets the application name associated with the task.
  #
  def application_name=(app)
    action = default_action(create_if_missing: true)
    action.Path = app
    app
  end

  # Returns the command line parameters for the task.
  #
  def parameters
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.Arguments
  end

  # Sets the parameters for the task. These parameters are passed as command
  # line arguments to the application the task will run. To clear the command
  # line parameters set it to an empty string.
  #
  def parameters=(param)
    action = default_action(create_if_missing: true)
    action.Arguments = param
    param
  end

  # Returns the working directory for the task.
  #
  def working_directory
    action = default_action(create_if_missing: false)
    action.nil? ? nil : action.WorkingDirectory
  end

  # Sets the working directory for the task.
  #
  def working_directory=(dir)
    action = default_action(create_if_missing: false)
    action.WorkingDirectory = dir
    dir
  end

  def compatibility
    @definition.Settings.Compatibility
  end

  def compatibility=(value)
    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381846(v=vs.85).aspx
    @definition.Settings.Compatibility = value
  end

  # Returns a set of trigger hashes with their indexes, for supported trigger
  # types. Returns nil for each unknown trigger types in the collection.
  #
  def triggers
    @definition.Triggers.count.times.map { |i| trigger(i) }
  end

  # Deletes the trigger at the specified index.
  #
  def delete_trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    index += 1
    @definition.Triggers.Remove(index)

    index
  end

  # Deletes all triggers
  def clear_triggers
    @definition.Triggers.Clear()
  end

  # Appends a new trigger for the currently active task.
  #
  def append_trigger(manifest_hash)
    Trigger::V2.append_trigger(@definition, manifest_hash)
  end

  def enabled
    @definition.Settings.Enabled
  end

  def enabled=(value)
    @definition.Settings.Enabled = value
  end

  private
  # :stopdoc:
  def self.task_service
    return @service unless @service.nil?

    @service = WIN32OLE.new('Schedule.Service')
    @service.connect()

    @service
  end

  def self.task_name_from_task_path(task_path)
    task_path.rpartition('\\')[2]
  end

  def self.folder_path_from_task_path(task_path)
    path = task_path.rpartition('\\')[0]

    path.empty? ? ROOT_FOLDER : path
  end

  def self.task(task_path)
    raise TypeError unless task_path.is_a?(String)
    service = task_service
    begin
      task_folder = service.GetFolder(folder_path_from_task_path(task_path))
      # https://msdn.microsoft.com/en-us/library/windows/desktop/aa381363(v=vs.85).aspx
      _task = task_folder.GetTask(task_name_from_task_path(task_path))
      return _task, _task.Definition
    rescue WIN32OLERuntimeError => e
      unless Error.is_com_error_type(e, Error::ERROR_FILE_NOT_FOUND)
        raise Puppet::Error.new( _("GetTask failed with: %{error}") % { error: e }, e )
      end
    end

    return nil, service.NewTask(0)
  end

  # Find the first TASK_ACTION_EXEC action
  def default_action(options = {})
    action = nil
    (1..@definition.Actions.count).each do |i|
      index_action = action_at(i)
      action = index_action if index_action.Type == TASK_ACTION_TYPE::TASK_ACTION_EXEC
      break if action
    end

    if action.nil? && options.fetch(:create_if_missing, false)
      action = @definition.Actions.Create(TASK_ACTION_TYPE::TASK_ACTION_EXEC)
    end

    action
  end

  def action_at(index)
    @definition.Actions.Item(index)
  rescue WIN32OLERuntimeError => err
    raise unless Error.is_com_error_type(err, Error::E_INVALIDARG)
    nil
  end

  # Returns a Win32OLE Trigger Object for the trigger at the given index for the
  # supplied definition.
  #
  # Returns nil if the index does not exist
  #
  # Note - This is a 1 based array (not zero)
  #
  def trigger_at(index)
    @definition.Triggers.Item(index)
  rescue WIN32OLERuntimeError => err
    raise unless Error.is_com_error_type(err, Error::E_INVALIDARG)
    nil
  end

  # Returns a hash that describes the trigger at the given index for the
  # current task.
  #
  def trigger(index)
    # The older V1 API uses a starting index of zero, wherease the V2 API uses one.
    # Need to increment by one to maintain the same behavior
    trigger_object = trigger_at(index + 1)
    trigger_object.nil? || Trigger::V2::TYPE_MANIFEST_MAP[trigger_object.Type].nil? ?
      # nil trigger definitions are unsupported ITrigger types
      nil :
      Trigger::V2.to_manifest_hash(trigger_object).merge!({ 'index' => index })
  end
end

end
end
end
