require 'json'

class TaskHelper
  attr_reader :debug_statements

  class Error < RuntimeError
    attr_reader :kind, :details, :issue_code

    def initialize(msg, kind, details = nil)
      super(msg)
      @kind = kind
      @issue_code = issue_code
      @details = details || {}
    end

    def to_h
      { 'kind' => kind,
        'msg' => message,
        'details' => details }
    end
  end

  def debug(statement)
    @debug_statements ||= []
    @debug_statements << statement
  end

  def task(params = {})
    msg = 'The task author must implement the `task` method in the task'
    raise TaskHelper::Error.new(msg, 'tasklib/not-implemented')
  end

  # Accepts a Data object and returns a copy with all hash keys
  # symbolized.
  def self.walk_keys(data)
    case data
    when Hash
      data.each_with_object({}) do |(k, v), acc|
        v = walk_keys(v)
        acc[k.to_sym] = v
      end
    when Array
      data.map { |v| walk_keys(v) }
    else
      data
    end
  end

  def self.run
    input = $stdin.read
    params = walk_keys(JSON.parse(input))

    # This method accepts a hash of parameters to run the task, then executes
    # the task. Unhandled errors are caught and turned into an error result.
    # @param [Hash] params A hash of params for the task
    # @return [Hash] The result of the task
    task   = new
    result = task.task(params)

    if result.instance_of?(Hash)
      $stdout.print JSON.generate(result)
    else
      $stdout.print result.to_s
    end
  rescue TaskHelper::Error => e
    $stdout.print({ _error: e.to_h }.to_json)
    exit 1
  rescue StandardError => e
    details = {
      'backtrace' => e.backtrace,
      'debug' => task.debug_statements
    }.compact

    error = TaskHelper::Error.new(e.message, e.class.to_s, details)
    $stdout.print({ _error: error.to_h }.to_json)
    exit 1
  end
end
