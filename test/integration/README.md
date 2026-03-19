# integration testing

## template for different behaviors on each OS

```ruby
# template

if os.family == 'debian' && os.release.start_with?('18.04')
  #
elsif os.family == 'debian' && os.release.start_with?('22.04')
  #
elsif os.family == 'debian' && os.release.start_with?('24.04')
  #
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end
```
