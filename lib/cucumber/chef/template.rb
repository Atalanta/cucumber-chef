require 'erubis'

module Cucumber
  module Chef

    class TemplateError < Error; end

    class Template

      def self.render(template, context=nil)
        self.render_template(self.load_template(template), context)
      end


    private

      def self.load_template(template)
        IO.read(template).chomp
      end

      def self.render_template(template, context)
        Erubis::Eruby.new(template).evaluate(:config => context)
      end

    end

  end
end
