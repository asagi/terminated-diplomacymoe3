# -*- coding: utf-8 -*-
# ワーカーの数
worker_processes 2

# ソケット
listen "/var/www/api.diplomacy.moe/tmp/sockets/moe-api.sock"
pid "/var/www/api.diplomacy.moe/tmp/pids/moe-api.pid"

# ログ
log = "${my_app}/log/unicorn.log"
stderr_path File.expand_path("log/unicorn.log", ENV["RAILS_ROOT"])
stdout_path File.expand_path("log/unicorn.log", ENV["RAILS_ROOT"])

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  unless old_pid == server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill :QUIT, File.read(old_pid).to_i
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
end
