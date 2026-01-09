module GeminiSqlChat
  class Message < ApplicationRecord
  acts_as_paranoid

  belongs_to :conversation, class_name: 'GeminiSqlChat::Conversation', foreign_key: 'gemini_sql_chat_conversation_id'

  validates :conversation, presence: true
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  # Scopes
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :ordered, -> { order(created_at: :asc) }

  # Actualizar el timestamp de la conversación al crear mensaje
  after_create :touch_conversation

  private

  def touch_conversation
    conversation.touch
  end
  end
end
