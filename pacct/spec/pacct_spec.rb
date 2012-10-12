require 'spec_helper'

describe Pacct::File do  
  it "correctly loads data" do
    file = Pacct::File.new('snapshot/pacct')
    n = 0
    file.each_entry do |entry|
      entry.user_id.should eql 0
      entry.user_name.should eql "root"
      entry.group_id.should eql 0
      entry.group_name.should eql "root"
      entry.command_name.should eql "accton"
      entry.start_time.should eql Time.at(1349741116)
      entry.wall_time.should eql 2.0
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
  
  it "throws an error when encountering unknown user/group IDs" do
    file = Pacct::File.new('snapshot/pacct_invalid_ids')
    file.each_entry do |entry|
      expect { entry.user_name }.to(
        raise_error(Errno::NOERROR.new('Unable to obtain user name for ID 4294967295').to_s))
      expect { entry.group_name }.to(
        raise_error(Errno::NOERROR.new('Unable to obtain group name for ID 4294967295').to_s))
    end
  end
end