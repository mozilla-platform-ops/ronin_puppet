require_relative 'spec_helper'

describe 'your_class_name' do
  let(:params) do
    {
      'packages_classes' => [
        'mercurial',
        'nodejs',
        'python2',
        'python2_psutil',
        'python2_zstandard',
        'python3',
        'python3_psutil',
        'python3_zstandard',
        'scres',
        'tooltool',
        'virtualenv',
        'wget',
        'xcode_cmd_line_tools',
        'zstandard',
        'virt_audio_s3'
      ],
      'packages::mercurial::version' => '6.4.5',
      'packages::nodejs::version' => '12.11.1',
      'packages::python2::version' => '2.7.18',
      'packages::python2_zstandard::version' => '0.11.1',
      'packages::python3::version' => '3.11.0',
      'packages::python3_zstandard::version' => '0.22.0',
      'packages::virtualenv::version' => '16.4.3',
      'packages::wget::version' => '1.20.3_1',
      'packages::xcode_cmd_line_tools::version' => '12.4',
      'packages::zstandard::version' => '1.3.8',
      'packages::virt_audio_s3::version' => '0.5.0'
    }
  end

  it 'should ensure that Mercurial is installed with the correct version' do
    is_expected.to contain_package('mercurial').with_ensure('6.4.5')
  end

  it 'should ensure that Node.js is installed with the correct version' do
    is_expected.to contain_package('nodejs').with_ensure('12.11.1')
  end

  it 'should ensure that Python2 is installed with the correct version' do
    is_expected.to contain_package('python2').with_ensure('2.7.18')
  end

  it 'should ensure that Python2 zstandard is installed with the correct version' do
    is_expected.to contain_package('python2_zstandard').with_ensure('0.11.1')
  end

  it 'should ensure that Python3 is installed with the correct version' do
    is_expected.to contain_package('python3').with_ensure('3.11.0')
  end

  it 'should ensure that Python3 zstandard is installed with the correct version' do
    is_expected.to contain_package('python3_zstandard').with_ensure('0.22.0')
  end

  it 'should ensure that Virtualenv is installed with the correct version' do
    is_expected.to contain_package('virtualenv').with_ensure('16.4.3')
  end

  it 'should ensure that Wget is installed with the correct version' do
    is_expected.to contain_package('wget').with_ensure('1.20.3_1')
  end

  it 'should ensure that Xcode Command Line Tools are installed with the correct version' do
    is_expected.to contain_package('xcode_cmd_line_tools').with_ensure('12.4')
  end

  it 'should ensure that Zstandard is installed with the correct version' do
    is_expected.to contain_package('zstandard').with_ensure('1.3.8')
  end

  it 'should ensure that Virt Audio S3 is installed with the correct version' do
    is_expected.to contain_package('virt_audio_s3').with_ensure('0.5.0')
  end
end
