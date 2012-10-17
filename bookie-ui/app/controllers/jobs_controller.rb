require 'rubygems'
require 'bookie'

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job.all
  end
end
