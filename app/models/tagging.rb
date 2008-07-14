# == Schema Information
# Schema version: 20080704045101
#
# Table name: taggings
#
#  id            :integer         not null, primary key
#  tag_id        :integer         not null
#  taggable_id   :integer         not null
#  taggable_type :string(255)     not null
#


# The Tagging join model. This model is automatically generated and added to your app if you run the tagging generator included with has_many_polymorphs.

class Tagging < ActiveRecord::Base 
  if table_exists?
    belongs_to :tag
    belongs_to :taggable, :polymorphic => true

  
    # If you also need to use <tt>acts_as_list</tt>, you will have to manage the tagging positions manually by creating decorated join records when you associate Tags with taggables.
    # acts_as_list :scope => :taggable
    
    # This callback makes sure that an orphaned <tt>Tag</tt> is deleted if it no longer tags anything.
    def after_destroy
      tag.destroy_without_callbacks if tag and tag.taggings.count == 0
    end    
  end
end