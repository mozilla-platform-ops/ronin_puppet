require_relative 'spec_helper'

describe 'your_class_name' do
    describe package('mercurial') do
      it { is_expected.to be_installed.with_version('6.4.5') }
    end

    describe package('nodejs') do
      it { is_expected.to be_installed.with_version('12.11.1') }
    end

    describe package('python2') do
      it { is_expected.to be_installed.with_version('2.7.18') }
    end

    describe package('python2_zstandard') do
      it { is_expected.to be_installed.with_version('0.11.1') }
    end

    describe package('python3') do
      it { is_expected.to be_installed.with_version('3.11.0') }
    end

    describe package('python3_zstandard') do
      it { is_expected.to be_installed.with_version('0.22.0') }
    end

    describe package('virtualenv') do
      it { is_expected.to be_installed.with_version('16.4.3') }
    end

    describe package('wget') do
      it { is_expected.to be_installed.with_version('1.20.3_1') }
    end

    describe package('xcode_cmd_line_tools') do
      it { is_expected.to be_installed.with_version('12.4') }
    end

    describe package('zstandard') do
      it { is_expected.to be_installed.with_version('1.3.8') }
    end

    describe package('virt_audio_s3') do
      it { is_expected.to be_installed.with_version('0.5.0') }
    end
  end
