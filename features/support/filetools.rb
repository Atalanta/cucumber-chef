def file_should_exist(file)
  File.exists?(File.expand_path(file)).should be_true
end

def file_should_contain(file, pattern)
  lines = File.foreach(File.expand_path(file)).map { |line| line.chomp }
  lines.find_index(pattern.chomp).should_not be_nil
end

