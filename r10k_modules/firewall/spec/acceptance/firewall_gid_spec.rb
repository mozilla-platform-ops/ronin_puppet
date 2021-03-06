require 'spec_helper_acceptance'

describe 'firewall gid' do
  before :all do
    iptables_flush_all_tables
    ip6tables_flush_all_tables
  end

  describe 'gid tests' do
    context 'when gid set to root' do
      pp1 = <<-PUPPETCODE
          class { '::firewall': }
          firewall { '801 - test':
            chain => 'OUTPUT',
            action => accept,
            gid => 'root',
            proto => 'all',
          }
      PUPPETCODE
      it 'applies' do
        apply_manifest(pp1, catch_failures: true)
        apply_manifest(pp1, catch_changes: do_catch_changes)
      end

      it 'contains the rule' do
        shell('iptables-save') do |r|
          expect(r.stdout).to match(%r{-A OUTPUT -m owner --gid-owner (0|root) -m comment --comment "801 - test" -j ACCEPT})
        end
      end
    end

    context 'when gid set to !root' do
      pp2 = <<-PUPPETCODE
          class { '::firewall': }
          firewall { '802 - test':
            chain => 'OUTPUT',
            action => accept,
            gid => '!root',
            proto => 'all',
          }
      PUPPETCODE
      it 'applies' do
        apply_manifest(pp2, catch_failures: true)
        apply_manifest(pp2, catch_changes: do_catch_changes)
      end

      it 'contains the rule' do
        shell('iptables-save') do |r|
          expect(r.stdout).to match(%r{-A OUTPUT -m owner ! --gid-owner (0|root) -m comment --comment "802 - test" -j ACCEPT})
        end
      end
    end

    context 'when gid set to 0' do
      pp3 = <<-PUPPETCODE
          class { '::firewall': }
          firewall { '803 - test':
            chain => 'OUTPUT',
            action => accept,
            gid => '0',
            proto => 'all',
          }
      PUPPETCODE
      it 'applies' do
        apply_manifest(pp3, catch_failures: true)
        apply_manifest(pp3, catch_changes: do_catch_changes)
      end

      it 'contains the rule' do
        shell('iptables-save') do |r|
          expect(r.stdout).to match(%r{-A OUTPUT -m owner --gid-owner (0|root) -m comment --comment "803 - test" -j ACCEPT})
        end
      end
    end

    context 'when gid set to !0' do
      pp4 = <<-PUPPETCODE
          class { '::firewall': }
          firewall { '804 - test':
            chain => 'OUTPUT',
            action => accept,
            gid => '!0',
            proto => 'all',
          }
      PUPPETCODE
      it 'applies' do
        apply_manifest(pp4, catch_failures: true)
        apply_manifest(pp4, catch_changes: do_catch_changes)
      end

      it 'contains the rule' do
        shell('iptables-save') do |r|
          expect(r.stdout).to match(%r{-A OUTPUT -m owner ! --gid-owner (0|root) -m comment --comment "804 - test" -j ACCEPT})
        end
      end
    end
  end
end
