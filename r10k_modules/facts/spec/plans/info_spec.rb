# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts::info' do
  include BoltSpec::Plans

  context 'an ssh target' do
    let(:target) { 'ssh://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'unix', 'family' => 'unix', 'release' => {} })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq(["#{target}: unix  (unix)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{target}" })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq([])
    end
  end

  context 'a winrm target' do
    let(:target) { 'winrm://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'win', 'family' => 'win', 'release' => {} })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq(["#{target}: win  (win)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{target}" })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq([])
    end
  end

  context 'a pcp target' do
    let(:target) { 'pcp://host' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq(["#{target}: any  (any)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{target}" })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq([])
    end
  end

  context 'a local target' do
    let(:target) { 'local://' }

    it 'contains OS information for target' do
      expect_task('facts').always_return('os' => { 'name' => 'any', 'family' => 'any', 'release' => {} })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq(["#{target}: any  (any)"])
    end

    it 'omits failed targets' do
      expect_task('facts').always_return('_error' => { 'msg' => "Failed on #{target}" })

      expect(run_plan('facts::info', 'targets' => [target]).value).to eq([])
    end
  end

  context 'ssh, winrm, and pcp targets' do
    let(:targets) { %w[ssh://host1 winrm://host2 pcp://host3] }

    it 'contains OS information for target' do
      expect_task('facts').return_for_targets(
        targets[0] => { 'os' => { 'name' => 'unix', 'family' => 'unix', 'release' => {} } },
        targets[1] => { 'os' => { 'name' => 'win', 'family' => 'win', 'release' => {} } },
        targets[2] => { 'os' => { 'name' => 'any', 'family' => 'any', 'release' => {} } }
      )

      expect(run_plan('facts::info', 'targets' => targets).value).to eq(
        ["#{targets[0]}: unix  (unix)", "#{targets[1]}: win  (win)", "#{targets[2]}: any  (any)"]
      )
    end

    it 'omits failed targets' do
      target_results = targets.each_with_object({}) do |target, h|
        h[target] = { '_error' => { 'msg' => "Failed on #{target}" } }
      end
      expect_task('facts').return_for_targets(target_results)

      expect(run_plan('facts::info', 'targets' => targets).value).to eq([])
    end
  end
end
