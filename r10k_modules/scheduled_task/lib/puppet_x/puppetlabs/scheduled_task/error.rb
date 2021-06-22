# frozen_string_literal: true

# module PuppetX
module PuppetX; end

# module PuppetX::PuppetLabs
module PuppetX::PuppetLabs; end

# module PuppetX::PuppetLabs::ScheduledTask
module PuppetX::PuppetLabs::ScheduledTask; end

# module PuppetX::PuppetLabs::ScheduledTask::Error
module PuppetX::PuppetLabs::ScheduledTask::Error
  # from C:\Program Files (x86)\Windows Kits\8.1\Include\shared\winerror.h
  MAX_32_BIT_VALUE = 0xFFFFFFFF

  # Returnes the signed value
  def self.to_signed_value(hresult)
    -(-hresult & MAX_32_BIT_VALUE)
  end

  # Checks if an error is a COM Error
  def self.com_error_type?(win_32_ole_runtime_error, hresult)
    # to_s(16) does not include 0x prefix
    # assume actual hex for error is what message contains - i.e. 80070002
    return true if win_32_ole_runtime_error.message.match?(%r{#{hresult.to_s(16)}})
    # if not, look for 2s complement (negative value) - i.e. -2147024894
    win_32_ole_runtime_error.message =~ %r{#{to_signed_value(hresult)}}m
  end

  # #define FACILITY_WIN32                   7
  # #define __HRESULT_FROM_WIN32(x) ((HRESULT)(x) <= 0 ? ((HRESULT)(x)) : ((HRESULT) (((x) & 0x0000FFFF) | (FACILITY_WIN32 << 16) | 0x80000000)))

  # The system cannot find the file specified.
  # WIN32 Error Code 2L (0x2)
  ERROR_FILE_NOT_FOUND                  = 0x80070002 # -2147024894

  # No mapping between account names and security IDs was done.
  # WIN32 Error CODE 1332L (0x534)
  ERROR_NONE_MAPPED                     = 0x80070534 # -2147023564

  # The Task Scheduler service must be configured to run in the System account
  # to function properly. Individual tasks may be configured to run in other accounts.
  # Win32 Error Code 6200L (0xA28)
  SCHED_E_SERVICE_NOT_LOCALSYSTEM       = 0x80070A28 # -2147022296

  # One or more arguments are invalid
  E_INVALIDARG                          = 0x80070057 # -2147024809

  # The task is ready to run at its next scheduled time.
  SCHED_S_TASK_READY                    = 0x00041300

  # The task is currently running.
  SCHED_S_TASK_RUNNING                  = 0x00041301

  # The task will not run at the scheduled times because it has been disabled.
  SCHED_S_TASK_DISABLED                 = 0x00041302

  # The task has not yet run.
  SCHED_S_TASK_HAS_NOT_RUN              = 0x00041303

  # There are no more runs scheduled for this task.
  SCHED_S_TASK_NO_MORE_RUNS             = 0x00041304

  # One or more of the properties that are needed to run this task on a
  # schedule have not been set.
  SCHED_S_TASK_NOT_SCHEDULED            = 0x00041305

  # The last run of the task was terminated by the user.
  SCHED_S_TASK_TERMINATED               = 0x00041306

  # Either the task has no triggers or the existing triggers are disabled
  # or not set.
  SCHED_S_TASK_NO_VALID_TRIGGERS        = 0x00041307

  # Event triggers don't have set run times.
  SCHED_S_EVENT_TRIGGER                 = 0x00041308

  # Trigger not found.
  SCHED_E_TRIGGER_NOT_FOUND             = 0x80041309 # -2147216631

  # One or more of the properties that are needed to run this task have
  # not been set.
  SCHED_E_TASK_NOT_READY                = 0x8004130A # -2147216630

  # There is no running instance of the task.
  SCHED_E_TASK_NOT_RUNNING              = 0x8004130B # -2147216629

  # The Task Scheduler Service is not installed on this computer.
  SCHED_E_SERVICE_NOT_INSTALLED         = 0x8004130C # -2147216628

  # The task object could not be opened.
  SCHED_E_CANNOT_OPEN_TASK              = 0x8004130D # -2147216627

  # The object is either an invalid task object or is not a task object.
  SCHED_E_INVALID_TASK                  = 0x8004130E # -2147216626

  # No account information could be found in the Task Scheduler security
  # database for the task indicated.
  SCHED_E_ACCOUNT_INFORMATION_NOT_SET   = 0x8004130F # -2147216625

  # Unable to establish existence of the account specified.
  SCHED_E_ACCOUNT_NAME_NOT_FOUND        = 0x80041310 # -2147216624

  # Corruption was detected in the Task Scheduler security database;
  # the database has been reset.
  SCHED_E_ACCOUNT_DBASE_CORRUPT         = 0x80041311 # -2147216623

  # Task Scheduler security services are available only on Windows NT.
  SCHED_E_NO_SECURITY_SERVICES          = 0x80041312 # -2147216622

  # The task object version is either unsupported or invalid.
  SCHED_E_UNKNOWN_OBJECT_VERSION        = 0x80041313 # -2147216621

  # The task has been configured with an unsupported combination of account
  # settings and run time options.
  SCHED_E_UNSUPPORTED_ACCOUNT_OPTION    = 0x80041314 # -2147216620

  # The Task Scheduler Service is not running.
  SCHED_E_SERVICE_NOT_RUNNING           = 0x80041315 # -2147216619

  # The task XML contains an unexpected node.
  SCHED_E_UNEXPECTEDNODE                = 0x80041316 # -2147216618

  # The task XML contains an element or attribute from an unexpected namespace.
  SCHED_E_NAMESPACE                     = 0x80041317 # -2147216617

  # The task XML contains a value which is incorrectly formatted or out of range.
  SCHED_E_INVALIDVALUE                  = 0x80041318 # -2147216616

  # The task XML is missing a required element or attribute.
  SCHED_E_MISSINGNODE                   = 0x80041319 # -2147216615

  # The task XML is malformed.
  SCHED_E_MALFORMEDXML                  = 0x8004131A # -2147216614

  # The task is registered, but not all specified triggers will start the
  # task, check task scheduler event log for detailed information.
  SCHED_S_SOME_TRIGGERS_FAILED          = 0x0004131B

  # The task is registered, but may fail to start. Batch logon privilege needs
  # to be enabled for the task principal.
  SCHED_S_BATCH_LOGON_PROBLEM           = 0x0004131C

  # The task XML contains too many nodes of the same type.
  SCHED_E_TOO_MANY_NODES                = 0x8004131D # -2147216611

  # The task cannot be started after the trigger's end boundary.
  SCHED_E_PAST_END_BOUNDARY             = 0x8004131E # -2147216610

  # An instance of this task is already running.
  SCHED_E_ALREADY_RUNNING               = 0x8004131F # -2147216609

  # The task will not run because the user is not logged on.
  SCHED_E_USER_NOT_LOGGED_ON            = 0x80041320 # -2147216608

  # The task image is corrupt or has been tampered with.
  SCHED_E_INVALID_TASK_HASH             = 0x80041321 # -2147216607

  # The Task Scheduler service is not available.
  SCHED_E_SERVICE_NOT_AVAILABLE         = 0x80041322 # -2147216606

  # The Task Scheduler service is too busy to handle your request.
  # Please try again later.
  SCHED_E_SERVICE_TOO_BUSY              = 0x80041323 # -2147216605

  # The Task Scheduler service attempted to run the task, but the task did
  # not run due to one of the constraints in the task definition.
  SCHED_E_TASK_ATTEMPTED                = 0x80041324 # -2147216604

  # The Task Scheduler service has asked the task to run.
  SCHED_S_TASK_QUEUED                   = 0x00041325

  # The task is disabled.
  SCHED_E_TASK_DISABLED                 = 0x80041326 # -2147216602

  # The task has properties that are not compatible with previous versions
  # of Windows.
  SCHED_E_TASK_NOT_V1_COMPAT            = 0x80041327 # -2147216601

  # The task settings do not allow the task to start on demand.
  SCHED_E_START_ON_DEMAND               = 0x80041328 # -2147216600

  # The combination of properties that task is using is not compatible
  # with the scheduling engine.
  SCHED_E_TASK_NOT_UBPM_COMPAT          = 0x80041329 # -2147216599

  # The task definition uses a deprecated feature.
  SCHED_E_DEPRECATED_FEATURE_USED       = 0x80041330 # -2147216592

  # The Event Log channel Microsoft-Windows-TaskScheduler must be enabled
  # to perform this operation.
  PLA_E_TASKSCHED_CHANNEL_NOT_ENABLED   = 0x80300111 # -2144337647
end
