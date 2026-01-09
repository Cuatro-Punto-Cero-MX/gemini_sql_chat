module GeminiSqlChat
  class Engine < ::Rails::Engine
    isolate_namespace GeminiSqlChat

    initializer "gemini_sql_chat.assets.precompile" do |app|
      app.config.assets.precompile += %w( gemini_sql_chat_manifest.js )
    end
  end
end
