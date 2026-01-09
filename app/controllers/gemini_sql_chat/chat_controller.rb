module GeminiSqlChat
  class ChatController < ::ApplicationController
    layout "default"
    helper Rails.application.routes.url_helpers
  before_action :authenticate_user!

  def index
    # Obtener conversaciones del usuario
    @conversations = GeminiSqlChat::Conversation.where(user_id: current_user.id).recent.limit(20)

    # Si hay una conversación activa en sesión, cargarla
    @current_conversation = nil
    if session[:current_chat_conversation_id]
      @current_conversation = GeminiSqlChat::Conversation.where(user_id: current_user.id).find_by(id: session[:current_chat_conversation_id])
    end

    render template: 'gemini_sql_chat/chat/index'
  end

  def query
    user_question = params[:question]
    conversation_id = params[:conversation_id]

    if user_question.blank?
      render json: { error: 'La pregunta no puede estar vacía' }, status: :bad_request
      return
    end

    begin
      # Obtener o crear conversación
      conversation = get_or_create_conversation(conversation_id)

      # Guardar mensaje del usuario
      user_message = conversation.messages.create!(
        role: 'user',
        content: user_question
      )

      # Obtener historial conversacional para contexto
      conversation_history = conversation.conversation_history

      # Generar SQL con contexto (ahora retorna hash con sql y suggested_questions)
      gemini_service = GeminiSqlChat::GeminiService.new
      gemini_response = gemini_service.generate_sql(user_question, conversation_history)

      # Extraer SQL y preguntas sugeridas
      sql_query = gemini_response[:sql]
      suggested_questions = gemini_response[:suggested_questions] || []

      # Ejecutar query
      results = gemini_service.execute_query(sql_query)

      # Formatear resultados
      formatted_results = results.map do |row|
        row.transform_keys(&:to_s)
      end

      # Guardar respuesta del asistente con los resultados y preguntas sugeridas
      assistant_message = conversation.messages.create!(
        role: 'assistant',
        content: "Se encontraron #{formatted_results.length} resultados",
        sql_query: sql_query,
        results_count: formatted_results.length,
        results_data: formatted_results,
        suggested_questions: suggested_questions
      )

      # Actualizar título de la conversación si es el primer mensaje
      conversation.update_title_from_first_message if conversation.messages.count == 2

      # Guardar conversation_id en sesión
      session[:current_chat_conversation_id] = conversation.id

      render json: {
        success: true,
        conversation_id: conversation.id,
        question: user_question,
        sql: sql_query,
        results: formatted_results,
        columns: formatted_results.first&.keys || [],
        count: formatted_results.length,
        suggested_questions: suggested_questions
      }
    rescue => e
      Rails.logger.error "Error en chat query: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end
  end

  def conversations
    conversations = GeminiSqlChat::Conversation.where(user_id: current_user.id).recent.limit(50)

    render json: {
      success: true,
      conversations: conversations.map { |c|
        {
          id: c.id,
          title: c.title,
          updated_at: c.updated_at.iso8601,
          messages_count: c.messages.count
        }
      }
    }
  end

  def load_conversation
    conversation_id = params[:id]
    conversation = GeminiSqlChat::Conversation.where(user_id: current_user.id).find_by(id: conversation_id)

    if conversation.nil?
      render json: { success: false, error: 'Conversación no encontrada' }, status: :not_found
      return
    end

    messages = conversation.messages.ordered.map do |msg|
      message_data = {
        id: msg.id,
        role: msg.role,
        content: msg.content,
        sql_query: msg.sql_query,
        results_count: msg.results_count,
        created_at: msg.created_at.iso8601
      }

      # Agregar resultados si existen
      if msg.results_data.present?
        message_data[:results] = msg.results_data
        message_data[:columns] = msg.results_data.first&.keys || []
      end

      # Agregar preguntas sugeridas si existen
      if msg.suggested_questions.present?
        message_data[:suggested_questions] = msg.suggested_questions
      end

      message_data
    end

    # Guardar como conversación actual
    session[:current_chat_conversation_id] = conversation.id

    render json: {
      success: true,
      conversation: {
        id: conversation.id,
        title: conversation.title,
        messages: messages
      }
    }
  end

  def new_conversation
    # Limpiar conversación actual de la sesión
    session[:current_chat_conversation_id] = nil

    render json: { success: true }
  end

  def delete_conversation
    conversation_id = params[:id]
    conversation = GeminiSqlChat::Conversation.where(user_id: current_user.id).find_by(id: conversation_id)

    if conversation.nil?
      render json: { success: false, error: 'Conversación no encontrada' }, status: :not_found
      return
    end

    conversation.destroy

    # Si era la conversación actual, limpiar sesión
    if session[:current_chat_conversation_id] == conversation.id
      session[:current_chat_conversation_id] = nil
    end

    render json: { success: true }
  end

  private

  def get_or_create_conversation(conversation_id)
    if conversation_id.present?
      # Buscar conversación existente
      conversation = GeminiSqlChat::Conversation.where(user_id: current_user.id).find_by(id: conversation_id)
      return conversation if conversation
    end

    # Crear nueva conversación
    GeminiSqlChat::Conversation.create!(user: current_user)
  end
  end
end
