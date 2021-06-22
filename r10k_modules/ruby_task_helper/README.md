# Ruby Task Helper

A Ruby helper library for writing [Puppet tasks](https://puppet.com/docs/bolt/latest/writing_tasks.html). It provides a class that handles error generation, simplifies JSON input and output, and makes testing your task easier. It requires Bolt >= 1.1 or Puppet Enterprise >= 2019.0.

#### Table of Contents

1. [Description](#description)
1. [Requirements](#requirements)
1. [Setup](#setup)
1. [Usage](#usage)
1. [Debugging](#debugging)
1. [Testing](#testing)

## Description

This library handles parsing JSON input, serializing the result as JSON output, and producing a formatted error message for errors.

## Requirements

This library works with Ruby 2.3 and later, though is tested using Ruby 2.4 and 2.5.

## Setup

To use this library, include this module in a [Puppetfile](https://puppet.com/docs/pe/2019.0/puppetfile.html):

```ruby
mod 'puppetlabs-ruby_task_helper'
```

Add it to your [task metadata](https://puppet.com/docs/bolt/latest/writing_tasks.html#concept-677)
```json
{
  "files": ["ruby_task_helper/files/task_helper.rb"],
  "input_method": "stdin"
}
```

## Usage

When writing your task include the library in your script, extend the `TaskHelper` module, and write the `task()` function. The `task()` function should accept its parameters as symbols, and should return a hash. The following is an example of a task that uses the library. All parameters will be symbolized including nested hash keys and hashes contained in arrays.

`mymodule/tasks/mytask.rb`
```ruby
#!/usr/bin/env ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"

class MyClass < TaskHelper
  def task(name: nil, **kwargs)
    {greeting: "Hi, my name is #{name}"}
  end
end

if __FILE__ == $0
  MyClass.run
end
```

You can then run the task like any other Bolt task:
```bash
bolt task run mymodule::task -t target.example.com name="Robert'); DROP TABLE Students;--"
```

You can additionally provide detailed errors by raising a `TaskError`, such as
```ruby
class MyTask < TaskHelper
  def task(**kwargs)
    raise TaskHelper::Error.new("my task error message",
                               "mytask/error-kind",
                               "Additional details")
```

## Debugging

When writing your task, it can be helpful to write debugging statement to locate
the source of any errors. The library includes a `debug` method that accepts arbitrary
values and logs it as a debugging statement. If the task errors, the list of
debugging statements will be included in the resulting `TaskError`.

The list of debugging statements can also be accessed from the task itself by calling
the `debug_statements` method. This can be used to include the debugging statements in
a `TaskError` that you explicitly raise.

Adding a debugging statement:
```ruby
debug "Result of method call: #{result}
```

Adding the list of debugging statements to a `TaskError`:
```ruby
raise TaskHelper::Error.new("my task error message",
                            "mytask/error-kind",
                            "debug" => debug_statements)
```

## Testing

By implementing the task as a method and not executing the task as a script
unless it is invoked directly it becomes much easier to write rspec tests for
your task. Make sure the task helper repo is checked out next to your module so
the relative requires work and you can write simple unit tests for the methods
of your task.

`mymodule/spec/mytask_spec.rb`
```ruby
require_relative '../tasks/mytask.rb'

describe 'MyTask' do
  let(:params) { { name: 'Lucy' } }
  let(:task) { MyTask.new() }

  it 'runs my task' do
    expect(task.task(params)).to eq({greeting: 'Hi, my name is Lucy'})
  end
end
```
