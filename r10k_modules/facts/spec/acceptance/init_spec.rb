# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'facts task', unless: fact_on(default, 'os.release.full') == '2008 R2' do
  include Beaker::TaskHelper::Inventory
  include BoltSpec::Run

  def bolt_config
    { 'modulepath' => RSpec.configuration.module_path }
  end

  def bolt_inventory
    hosts_to_inventory.merge('features' => ['puppet-agent'])
  end

  operating_system_fact = fact('operatingsystem')
  os_family_fact = fact('osfamily')
  platform = fact('os.name')
  release = fact('os.release.full')

  describe 'puppet facts' do
    it 'includes legacy and structured facts' do
      result = run_task('facts', 'default', {})
      expect(result[0]['status']).to eq('success')
      facts = result[0]['result']

      expect(facts).to include('osfamily', 'operatingsystem', 'os')
      expect(facts['osfamily']).to eq(os_family_fact)
      expect(facts['operatingsystem']).to eq(operating_system_fact)
      expect(facts['os']['family']).to eq(os_family_fact)
      expect(facts['os']['release']['full']).to eq(release)
    end
  end
end
