require 'rufus-scheduler'


service 'timer' do

  listener 'every' do
    start do |data|
      if data['minutes']
        every = "#{data['minutes']}m"
      elsif data['seconds']
        every = "#{data['seconds']}s"
      elsif data['seconds'] && data['minutes']
        fail "pick one, minutes or seconds, but you can't use both"
      else
        fail 'no duration specified'
      end

      info "starting timer every #{every}"

      @scheduler = Rufus::Scheduler.new
      begin
        @scheduler.every every do
          time=Time.now.to_s
          info "trigger time at #{time}"
          start_workflow({:time_run=>time})
        end
      rescue
        fail "The time specified `#{every}` is invalid"
      end

    end
    stop do |data|
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
          start_workflow({:time_run=>Time.now.to_s})
        end
      rescue => ex
        fail "The crontab entry `#{crontab}` was invalid.", exception:ex
      end

    end
    stop do |data|
      scheduler.stop
    end
  end


end
