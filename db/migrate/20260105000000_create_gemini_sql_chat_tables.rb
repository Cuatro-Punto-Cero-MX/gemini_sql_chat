class CreateGeminiSqlChatTables < ActiveRecord::Migration[7.1]
  def change
    create_table :gemini_sql_chat_conversations do |t|
      t.references :user, null: false
      t.string :title
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :gemini_sql_chat_conversations, :deleted_at

    create_table :gemini_sql_chat_messages do |t|
      t.references :gemini_sql_chat_conversation, null: false, foreign_key: true, index: { name: 'index_gemini_messages_on_conversation_id' }
      t.string :role
      t.text :content
      t.text :sql_query
      t.integer :results_count
      t.json :results_data
      t.json :suggested_questions
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :gemini_sql_chat_messages, :deleted_at
  end
end
