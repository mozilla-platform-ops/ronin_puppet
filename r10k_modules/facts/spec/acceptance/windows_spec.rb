# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'facts task', if: fact('osfamily') == 'windows' do
  include Beaker::TaskHelper::Inventory
  include BoltSpec::Run

  def bolt_config
    { 'modulepath' => RSpec.configuration.module_path }
  end

  def bolt_inventory
    hosts_to_inventory
  end

  os_family_fact = fact('osfamily')
  platform = fact('os.name')
  release = fact('os.release.full')

  describe 'bash facts implementation', unless: fact_on(default, 'os.release.full') == '2008 R2' do
    it 'returns facts json' do
      result = run_task('facts::powershell', 'default', {})
      facts = result[0]['result']
      expect(facts).to include('os')
      expect(facts['os']). to include('family', 'name', 'release')
      expect(facts['os']['family']).to match(/#{os_family_fact}/)
      expect(facts['os']['name']).to match(/#{platform}/)
      expect(release).to match(/#{facts['os']['release']['full']}/)
    end
  end
end
