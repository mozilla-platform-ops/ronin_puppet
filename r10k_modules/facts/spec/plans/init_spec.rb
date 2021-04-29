# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/plans'

describe 'facts' do
  include BoltSpec::Plans

  let(:node) { '' }
  let(:target) { Bolt::Target.new(node) }

  def fact_output(node_ = node)
    { 'fqdn' => node_ }
  end

  def err_output(node_ = node)
    { '_error' => { 'msg' => "Failed on #{node_}" } }
  end

  def results(output)
    Bolt::ResultSet.new([Bolt::Result.new(target, value: output)])
  end

  context 'an ssh target' do
    let(:node) { 'ssh://host' }

    it 'adds facts to the Target' do
      expect_task('facts').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output).returns(fact_output)

      expect(run_plan('facts', 'targets' => [node]).value).to eq(results(fact_output))
    end

    it 'does not mask errors' do
      expect_task('facts').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'targets' => [node]).value.msg).to eq("Plan aborted: run_task 'facts' failed on 1 target")
    end
  end

  context 'a winrm target' do
    let(:node) { 'winrm://host' }

    it 'adds facts to the Target' do
      expect_task('facts').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output).returns(fact_output)

      expect(run_plan('facts', 'targets' => [node]).value).to eq(results(fact_output))
    end

    it 'does not mask errors' do
      expect_task('facts').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'targets' => [node]).value.msg).to eq("Plan aborted: run_task 'facts' failed on 1 target")
    end
  end

  context 'a pcp target' do
    let(:node) { 'pcp://host' }

    it 'adds facts to the Target' do
      expect_task('facts').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output).returns(fact_output)

      expect(run_plan('facts', 'targets' => [node]).value).to eq(results(fact_output))
    end

    it 'does not mask errors' do
      expect_task('facts').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'targets' => [node]).value.msg).to eq("Plan aborted: run_task 'facts' failed on 1 target")
    end
  end

  context 'a local target' do
    let(:node) { 'local://' }

    it 'adds facts to the Target' do
      expect_task('facts').always_return(fact_output)
      inventory.expects(:add_facts).with(target, fact_output).returns(fact_output)

      expect(run_plan('facts', 'targets' => [node]).value).to eq(results(fact_output))
    end

    it 'does not mask errors' do
      expect_task('facts').always_return(err_output)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'targets' => [node]).value.msg).to eq("Plan aborted: run_task 'facts' failed on 1 target")
    end
  end

  context 'ssh, winrm, and pcp targets' do
    let(:nodes) { %w[ssh://host1 winrm://host2 pcp://host3] }

    it 'contains OS information for target' do
      target_results = nodes.each_with_object({}) { |node, h| h[node] = fact_output(node) }
      expect_task('facts').return_for_targets(target_results)
      nodes.each do |node|
        inventory.expects(:add_facts).with(Bolt::Target.new(node), fact_output(node)).returns(fact_output(node))
      end

      result_set = Bolt::ResultSet.new(
        nodes.map { |node| Bolt::Result.new(Bolt::Target.new(node), value: fact_output(node)) }
      )
      expect(run_plan('facts', 'targets' => nodes).value).to eq(result_set)
    end

    it 'does not mask errors' do
      target_results = nodes.each_with_object({}) { |node, h| h[node] = err_output(node) }
      expect_task('facts').return_for_targets(target_results)
      inventory.expects(:add_facts).never

      expect(run_plan('facts', 'targets' => nodes).value.msg).to eq("Plan aborted: run_task 'facts' failed on 3 targets")
    end
  end
end
