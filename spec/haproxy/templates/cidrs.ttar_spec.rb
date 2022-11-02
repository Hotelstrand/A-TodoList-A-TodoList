# frozen_string_literal: true

require 'rspec'

describe 'config/cidrs.ttar' do
  let(:template) { haproxy_job.temp