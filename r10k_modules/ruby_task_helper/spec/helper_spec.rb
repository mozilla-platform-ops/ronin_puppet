require_relative '../files/task_helper'
require 'json'

class EmptyTask < TaskHelper; end

class ErrorTask < TaskHelper
  def task(name: nil)
    raise TaskHelper::Error.new('task error message',
                                'task/error-kind',
                                'Additional details')
  end
end

class DebugTask < TaskHelper
  def task(name: nil)
    debug('debugging statement')
    debug('another debugging statement')
    raise StandardError, 'There was an error'
  end
end

class EchoTask < TaskHelper
  def task(name: nil)
    { 'result': "Hi, my name is #{name}" }
  end
end

class SymbolizeTask < TaskHelper
  def task(params)
    # Test that the keys have been symbolized.
    symbols = {
      nested_hash: params.dig(:top_level, :nested_key),
      array_hash: params[:array_keys].first[:array_key]
    }
    # Return the parameters merged with the symbols for
    # verification in test.
    result = params.merge(symbols)
    { 'result': JSON.dump(result) }
  end
end

describe 'EmptyTask' do
  it 'returns no method when task() is not provided' do
    allow($stdin).to receive(:read).and_return('{"name": "Lucy"}')
    msg = 'The task author must implement the `task` method in the task'
    result = { _error:
               { kind: 'tasklib/not-implemented',
                 msg: msg,
                 details: {} } }
    # This needs to be done before the process that exits is run
    expect($stdout).to receive(:print).with(result.to_json)

    begin
      EmptyTask.run
    rescue SystemExit => e
      expect(e.status).to eq(1)
    else
      raise 'The EmptyTask test did not exit 1 as expected'
    end
  end
end

describe 'ErrorTask' do
  it 'raises an error' do
    allow($stdin).to receive(:read).and_return('{"name": "Lucy"}')
    result = { _error: { kind: 'task/error-kind',
                         msg: 'task error message',
                         details: 'Additional details' } }
    # This needs to be done before the process that exits is run
    expect($stdout).to receive(:print).with(result.to_json)

    begin
      ErrorTask.run
    rescue SystemExit => e
      expect(e.status).to eq(1)
    else
      raise 'The ErrorTask test did not exit 1 as expected'
    end
  end
end

describe 'DebugTask' do
  it 'raises an error with debugging statements' do
    allow($stdin).to receive(:read).and_return('{"name": "Tom"}')
    regex = /\["debugging statement","another debugging statement"\]/

    # This needs to be done before the process that exits is run
    expect($stdout).to receive(:print).with(regex)

    begin
      DebugTask.run
    rescue SystemExit => e
      expect(e.status).to eq(1)
    else
      raise 'The DebugTask test did not exit 1 as expected'
    end
  end
end

describe 'EchoTask' do
  it 'runs an echo task' do
    allow($stdin).to receive(:read).and_return('{"name": "Lucy"}')
    out = JSON.dump('result' => 'Hi, my name is Lucy')
    expect($stdout).to receive(:print).with(out)
    EchoTask.run
  end
end

describe 'SymbolizeTask' do
  it 'recieves parameters hash with symbolized keys' do
    params = {
      'top_level' => { 'nested_key' => 'foo' },
      'array_keys' => [{ 'array_key' => 'bar' }]
    }
    # The task will only return these values if the keys
    # are properly symbolized.
    symbols = { nested_hash: 'foo', array_hash: 'bar' }
    allow($stdin).to receive(:read).and_return(JSON.dump(params))
    # In order to verify that symbolizing keys has not corrupted
    # the structure of the parameters the task returns the params
    # hash it received. This is merged with the result of looking
    # up the symbolized keys.
    out = JSON.dump('result' => JSON.dump(params.merge(symbols)))
    expect($stdout).to receive(:print).with(out)
    SymbolizeTask.run
  end
end
