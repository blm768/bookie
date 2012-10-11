require 'spec_helper'

describe Pacct::File do
  before(:each) do
    @file = Pacct::File.new('snapshot/pacct')
  end
  
  it "correctly loads data" do
    n = 0
    @file.each_entry do |entry|
      entry.user_id.should eql 0
      entry.user_name.should eql "root"
      entry.group_id.should eql 0
      entry.group_name.should eql "root"
      entry.command_name.should eql "accton"
      entry.start_time.should eql Time.at(1349741116)
      entry.wall_time.should eql 0
      entry.user_time.should eql 0
      entry.system_time.should eql 0
      entry.cpu_time.should eql 0
      entry.average_mem_usage.should eql 979
      entry.exit_code.should eql 0
      n += 1
    end
    n.should eql 1
  end
  
  it "thows an error if the file is not found" do
    expect { Pacct::File.new('snapshot/abc') }.to raise_error
  end
end