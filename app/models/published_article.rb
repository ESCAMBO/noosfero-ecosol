class PublishedArticle < Article
  before_create do |article|
    unless article.parent
      parent = article.reference_article.parent
      if parent && parent.blog? && article.profile.has_blog?
        article.parent = article.profile.blog
      end
    end
  end

  def self.short_description
    _('Reference to other article')
  end

  def self.description
    _('A reference to another article published in another profile')    
  end

  before_validation_on_create :update_name
  def update_name
    self.name = self.reference_article.name if self.name.blank?
  end

  def author
    if reference_article
      reference_article.author
    else
      profile
    end
  end

  def to_html(options={})
    reference_article ? reference_article.to_html : ('<em>' + _('The original text was removed.') + '</em>')
  end

  def abstract
    reference_article && reference_article.abstract
  end

end
