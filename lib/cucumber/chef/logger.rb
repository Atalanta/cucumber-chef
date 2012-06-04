module Cucumber
  module Chef

    class LoggerError < Error; end

    class Logger < ::Logger
      attr_accessor :stdout, :stderr, :stdin

      SEVERITIES = Severity.constants.inject([]) {|arr,c| arr[Severity.const_get(c)] = c; arr}

      def initialize(redirect=false)
        @redirect = redirect
        #@stdout, @stderr, @stdin = StringIO.new, StringIO.new, StringIO.new

        config_path = File.join(Cucumber::Chef.locate_parent(".chef"), ".cucumber-chef")
        FileUtils.mkdir_p(config_path)
        log_file = File.join(config_path, "cucumber-chef.log")

        super(log_file, 7, (1024 * 1024))
        set_log_level
      end

      def parse_caller(at)
        if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
          file = Regexp.last_match[1]
          line = Regexp.last_match[2]
          method = Regexp.last_match[3]
          "#{File.basename(file)}:#{line}:#{method} | "
        else
          ""
        end
      end

      def add(severity, message = nil, progname = nil, &block)
        return if @level > severity

        called_by = parse_caller(caller[1])

        message = [message, progname, (block && block.call)].delete_if{|i| i == nil}.join(": ")
        message = "%19s.%06d | %5s | %5s | %s%s\n" % [Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"), Time.now.utc.usec, Process.pid.to_s, SEVERITIES[severity], called_by, message]

        #buffer << message
        #auto_flush
        if @redirect
          STDOUT.puts(message)
          STDOUT.flush if STDOUT.respond_to?(:flush)
        end

        @logdev.write(message)

        true
      end

      def set_log_level(level="INFO")
        log_level = (ENV['LOG_LEVEL'] || level)
        self.level = Cucumber::Chef::Logger.const_get(log_level.to_s.upcase)
      end

    end

  end
end
