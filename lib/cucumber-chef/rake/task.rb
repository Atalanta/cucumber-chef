require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

namespace :cc do

  desc "Run features in a style suitable for Continuous Integration"
  task :ci do |t|

    def feature_dir(dir, &block)
      puts("=" * 80)
      puts("feature_dir(#{dir.inspect})")
      puts("=" * 80)

      system(%(echo "<li /><p>#{File.basename(dir)}<ul>" | tee -a #{@index_html}))
      block.call
      system(%(echo "</p></ul>" | tee -a #{@index_html}))
    end

    def run_feature(feature_file)
      puts("=" * 80)
      puts("run_feature(#{feature_file.inspect})")
      puts("=" * 80)

      filename = feature_file.gsub(/(\w*).feature/, '\1.html')
      puts("#{feature_file} -> public/#{filename}")

      system(%(mkdir -pv #{File.dirname("public/#{filename}")}))

      push = (@pushed ? nil : %(PUSH="YES"))
      output_file = File.join(@output_dir, filename)
      command = [push, "bundle exec cucumber", "features/support", feature_file, ENV['EXTRA_CUCUMBER_ARGS'], "--format html", "--out", output_file].flatten.compact.join(" ")
      @pushed = true if !@pushed
      puts("command=#{command.inspect}")
      system(command)
      @exit_codes << $?.exitstatus

      passed = "<font style='font-weight: bold; color: green;'>PASSED</font>"
      failed = "<font style='font-weight: bold; color: red;'>FAILED</font>"
      status = ((@exit_codes[-1] == 0) ? passed : failed)

      system(%(echo "<li /><a href='#{filename}'>#{File.basename(filename.gsub('.html', ''))}</a> (#{status})" | tee -a #{@index_html}))
    end

    @output_dir = File.join(Dir.pwd, "public")
    @index_html = File.join(@output_dir, "index.html")
    @pushed = false
    @exit_codes = Array.new

    puts("Cleaning up...")
    system(%(rm -rfv .cucumber-chef/aws/artifacts))
    system(%(rm -rfv public))
    system(%(mkdir -v public))

    puts("Generating Cucumber-Chef html reports...")

    system(%(echo "<html><head><title>Cucumber-Chef Report</title></head><body>" | tee public/index.html))
    system(%(echo "<h2>Cucumber-Chef Report</h2><ul>" | tee -a public/index.html))
    Dir.glob("features/*").each do |fdir|
      if File.directory?(fdir)
        if (ffiles = Dir.glob("#{fdir}/*.feature")).count > 0
          feature_dir(fdir) do
            ffiles.each do |ffile|
              run_feature(ffile)
            end
          end
        end
      else
        run_feature(fdir)
      end
    end
    system(%(echo "</ul></body></html>" | tee -a public/index.html))

    # If we had a failure be sure to surface it
    exit_code = (@exit_codes.any?{ |ec| ec != 0 } ? 1 : 0)
    exit(exit_code)
  end

  Cucumber::Rake::Task.new(:cucumber) do |t|
    feature_dirs = Array.new

    feature_dir_glob = File.join(Dir.pwd, "*cookbook*", "*", "*feature*")
    feature_dirs << Dir.glob(feature_dir_glob)

    feature_dir_glob = File.join(Dir.pwd, "*feature*")
    feature_dirs << Dir.glob(feature_dir_glob)

    opts = [
      "--exclude support/cookbooks",
      "--exclude support/data_bags",
      "--exclude support/environments",
      "--exclude support/keys",
      "--exclude support/roles",
      feature_dirs
    ].flatten.compact.join(" ")

    t.cucumber_opts = opts
  end

end
