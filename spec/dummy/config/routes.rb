Rails.application.routes.draw do
  mount GeminiSqlChat::Engine => "/gemini_sql_chat"
end
