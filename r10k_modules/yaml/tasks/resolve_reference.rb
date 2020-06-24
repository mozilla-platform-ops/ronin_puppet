#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'yaml'

class YAMLReference < TaskHelper
  def task(**opts)
    path = opts[:filepath]
    boltdir = opts[:_boltdir]
    full_path = if boltdir
                  File.expand_path(path, boltdir)
                else
                  File.expand_path(path)
                end
    data = YAML.safe_load(File.read(full_path))
    { value: data }
  end
end

if $PROGRAM_NAME == __FILE__
  YAMLReference.run
end
