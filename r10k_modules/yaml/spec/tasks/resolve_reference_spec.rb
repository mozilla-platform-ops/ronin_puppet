# frozen_string_literal: true

require 'spec_helper'
require_relative '../../tasks/resolve_reference.rb'

describe YAMLReference do
  let(:data) { { 'expected' => 'data' } }
  let(:path) { 'my_data.yaml' }

  it 'loads a file relative to the boltdir' do
    Dir.mktmpdir do |boltdir|
      full_path = File.join(boltdir, path)
      File.write(full_path, data.to_yaml)
      expect(subject.task(filepath: path, _boltdir: boltdir)).to eq(value: data)
    end
  end

  it 'loads an absolute path' do
    Dir.mktmpdir do |boltdir|
      full_path = File.join(boltdir, path)
      File.write(full_path, data.to_yaml)
      expect(subject.task(filepath: full_path, _boltdir: boltdir)).to eq(value: data)
    end
  end
end
