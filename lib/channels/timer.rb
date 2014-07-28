# encoding: UTF-8

require 'rufus-scheduler'

service 'timer' do
  listener 'every' do
    start do |params|
      minutes = params['minutes']
      seconds = params['seconds']

      fail 'Seconds or Minutes, but not both' if seconds && minutes
      fail 'Seconds or Minutes must be specified' if !seconds && !minutes

      every = "#{minutes}m" if minutes
      every = "#{seconds}s" if seconds

      info "Starting timer every #{every}"

      @scheduler = Rufus::Scheduler.new
      begin
        @scheduler.every every do
          time = Time.now.to_s
          info "Trigger time at #{time}"
          start_workflow time_run: time
        end
      rescue
        fail "The time specified `#{every}` is invalid"
      end

    end
    stop do |_data|
      @scheduler.stop
    end
  end

  listener 'cron' do

    scheduler = Rufus::Scheduler.new

    start do |data|
      crontab = data['crontab']
      info "Starting timer using the crontab `#{crontab}`"

      fail 'No crontab specified' if !crontab || crontab.empty?

      begin
        scheduler.cron crontab do
          start_workflow time_run: Time.now.to_s
        end
      rescue => ex
        fail "The crontab entry `#{crontab}` was invalid.", exception: ex
      end

    end
    stop do |_data|
      scheduler.stop
    end
  end
end
