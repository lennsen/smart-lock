require 'csv'

class ReportsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_server

  def handle
    # we need to process the csv file sent in the request
    if Rails.env.development?
      Entry.delete_all
      Lock.delete_all
    end

    report = params[:report].open

    csv_options = { col_sep: ',', headers: :first_row }

    CSV.parse(report, csv_options) do |timestamp, lock_id, kind, status_change|
      lock = Lock.find_by_id(lock_id[1])
      if lock
        # we need to update the status of the value of the status change
        lock.status = status_change[1]
        lock.save
      else
        lock = Lock.create(id: lock_id[1], kind: kind[1], status: status_change[1])
      end

      Entry.create(timestamp: timestamp[1], status_change: status_change[1], lock: lock)
    end

    render json: { message: "Congrats, your report has been processed. Now you have #{Lock.count} locks and #{Entry.count} entries." }
  end

  def authenticate_server
    # how do we authenticate?
    # first we need to find the server instance associated with code_name that
    # was passed down to us in the request
    code_name = request.headers["X-Server-CodeName"]
    server = Server.find_by(code_name: code_name)
    access_token = request.headers["X-Server-Token"]
    unless server && server.access_token == access_token
      render json: { message: "Wrong credentials" }
    end
  end
end
