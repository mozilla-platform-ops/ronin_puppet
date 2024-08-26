require_relative 'spec_helper'

describe 'worker_metadata' do
  let(:params) do
    {
      'workerId'       => '%{lookup(\'gw.worker_id\')}',
      'workerGroup'    => '%{lookup(\'gw.worker_group\')}',
      'workerType'     => '%{lookup(\'gw.worker_type\')}',
      'provisionerId'  => '%{lookup(\'gw.provisioner_id\')}',
    }
  end

  it 'should correctly look up and set workerId' do
    is_expected.to contain('workerId').with_value('%{lookup(\'gw.worker_id\')}')
  end

  it 'should correctly look up and set workerGroup' do
    is_expected.to contain('workerGroup').with_value('%{lookup(\'gw.worker_group\')}')
  end

  it 'should correctly look up and set workerType' do
    is_expected.to contain('workerType').with_value('%{lookup(\'gw.worker_type\')}')
  end

  it 'should correctly look up and set provisionerId' do
    is_expected.to contain('provisionerId').with_value('%{lookup(\'gw.provisioner_id\')}')
  end
end
