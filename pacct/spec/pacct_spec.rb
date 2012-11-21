require 'spec_helper'

describe Pacct::Log do
  before(:each) do
    @log = Pacct::Log.new('snapshot/pacct')
  end
  
  #To do: test write methods
  
  it "correctly loads data" do
    n = 0
    @log.each_entry do |entry|
      entry.process_id.should eql 1742
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
      entry.memory.should eql 979
      entry.exit_code.should eql 0
      n += 1
    end
    n.should eql 1
  end
  
  it "correctly handles the seek parameter" do
    n = 0
    @log.each_entry(1) do |e|
      n += 1
    end
    n.should eql 0
    #To do: out-of-range seek
  end
  
  it "can read data more than once" do
    2.times do
      @log.each_entry do |e|
        e.user_name.should eql 'root'
      end
    end
  end
  
  it "correctly finds the last entry" do
    Helpers::double_log('snapshot/pacct_write') do |log|
      entry = log.last_entry
      entry.should_not eql nil
      entry.exit_code.should eql 1
    end
    Pacct::Log.new('/dev/null').last_entry.should eql nil
  end
  
  it "raises an error if the file is not found" do
    expect { Pacct::Log.new('snapshot/abc') }.to raise_error
  end
  
  it "raises an error when the file is the wrong size" do
    expect { Pacct::Log.new('snapshot/pacct_invalid_length') }.to raise_error
  end
  
  it "raises an error when encountering unknown user/group IDs" do
    log = Pacct::Log.new('snapshot/pacct_invalid_ids')
    log.each_entry do |entry|
      #This assumes that these users and groups don't actually exist.
      #If, for some odd reason, they _do_ exist, this test will fail.
      expect { entry.user_name }.to raise_error(
        Errno::ENODATA.new('Unable to obtain user name for ID 4294967295').to_s)
      expect { entry.user_name = '_____ _' }.to raise_error(
         Errno::ENODATA.new("Unable to obtain user ID for name '_____ _'").to_s) 
      expect { entry.group_name }.to raise_error(
        Errno::ENODATA.new('Unable to obtain group name for ID 4294967295').to_s)
      expect { entry.group_name = '_____ _' }.to raise_error(
        Errno::ENODATA.new("Unable to obtain group ID for name '_____ _'").to_s) 
    end
  end
  
  ENTRY_DATA = {
    :process_id => 3,
    :user_name => 'root',
    :group_name => 'root',
    :command_name => 'ls',
    :start_time => Time.new(2012, 1, 1),
    :wall_time => 10.0,
    :user_time => 1,
    :system_time => 1,
    :memory => 100000,
    :exit_code => 2}
  
  it "correctly writes entries at the end of the file" do
    e = Pacct::Entry.new
    ENTRY_DATA.each_pair do |key, value|
      e.method((key.to_s + '=').intern).call(value)
    end
    FileUtils.cp('snapshot/pacct', 'snapshot/pacct_write')
    log = Pacct::Log.new('snapshot/pacct_write', 'r+b')
    log.write_entry(e)
    e = log.last_entry
    e.should_not eql nil
    ENTRY_DATA.each_pair do |key, value|
      e.send(key).should eql value
    end
    FileUtils.rm('snapshot/pacct_write')
  end
  
  it "raises an error if writing fails"
  
  it "creates files when opened in write mode" do
    FileUtils.rm('snapshot/abc') if File.exists?('snapshot/abc')
    log = Pacct::Log.new('snapshot/abc', 'wb')
    File.exists?('snapshot/abc').should eql true
    FileUtils.rm('snapshot/abc')
  end
end

module Helpers
  def self.double_log(filename)
    FileUtils.cp('snapshot/pacct', filename)
    log = Pacct::Log.new(filename, 'r+b')
    entry = nil
    log.each_entry do |e|
      entry = e
      break
    end
    entry.exit_code = 1
    log.write_entry(entry)
    yield log
    FileUtils.rm(filename)
  end
end