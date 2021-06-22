require_relative './mytask.rb'
# An example of testing a task using the helper

describe 'MyTask' do
  let(:params) { { name: 'Lucy' } }
  let(:task) { MyTask.new() }

  it 'runs my task' do
    expect(task.task(params)).to eq({greeting: 'Hi, my name is Lucy'})
  end
end
