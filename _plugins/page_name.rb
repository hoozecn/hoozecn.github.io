module PageName
  class PageNameTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
    end

    def render(context)
      name = Jekyll.configuration({})['name']
      page = context['page']
      if page['title'] != nil
        name = "#{page['title']} - #{name}"
      end
      name
    end
  end
end

Liquid::Template.register_tag('page_name', PageName::PageNameTag)
