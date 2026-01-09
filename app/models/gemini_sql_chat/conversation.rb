module GeminiSqlChat
  class Conversation < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  has_many :messages, class_name: 'GeminiSqlChat::Message', foreign_key: 'gemini_sql_chat_conversation_id', dependent: :destroy

  validates :user_id, presence: true

  # Generar título por defecto al crear
  after_create :set_default_title

  # Scope para obtener conversaciones ordenadas por actividad reciente
  scope :recent, -> { order(updated_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  # Obtener los últimos N mensajes para contexto
  def recent_messages(limit = 10)
    messages.order(created_at: :asc).last(limit)
  end

  # Construir array de mensajes en formato para Gemini
  def conversation_history
    recent_messages.map do |msg|
      {
        role: msg.role,
        content: msg.content,
        sql_query: msg.sql_query
      }
    end
  end

  # Actualizar título basado en el primer mensaje
  def update_title_from_first_message
    return if title_was_customized?

    first_message = messages.where(role: 'user').first
    if first_message
      new_title = first_message.content.truncate(50, omission: '...')
      update_column(:title, new_title)
    end
  end

  private

  def set_default_title
    return if title.present?
    update_column(:title, "Conversación #{created_at.strftime('%d/%m/%Y %H:%M')}")
  end

  def title_was_customized?
    # Verificar si el título fue modificado manualmente
    # (no es el título por defecto ni el basado en primer mensaje)
    return false if title.blank?
    !title.start_with?('Conversación') || messages.where(role: 'user').empty?
  end
  end
end
