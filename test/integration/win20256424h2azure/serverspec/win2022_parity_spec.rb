Dir[File.expand_path('../../win2022642009azure/serverspec/*_spec.rb', __dir__)].grep_v(/microsoft_tools_spec\.rb$/).sort.each { |spec| require spec }
