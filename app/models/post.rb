class Post < ApplicationRecord
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true, length: { maximum: 65_535 }

  attr_accessor :tag_names
  before_save :save_tags
  paginates_per 9

  # Ransackで検索可能にするフィールド
  def self.ransackable_attributes(auth_object = nil)
    ["title", "content"]
  end

  # Ransackで検索可能にするアソシエーション
  def self.ransackable_associations(auth_object = nil)
    ["user", "tags"]
  end

  has_rich_text :content
  has_one_attached :thumbnail

  belongs_to :user
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags

  private

  def save_tags
    self.tags.clear
    if tag_names.present?
      tag_names.split(',').map(&:strip).uniq.reject(&:empty?).each do |tag_name|
        # 既存のタグを利用or新しいタグを作成する
        tag = Tag.find_or_create_by(name: tag_name)
        self.tags << tag
      end
    end
  end
end

