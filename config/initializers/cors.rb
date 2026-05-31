# Be sure to restart your server when you modify this file.
#
# Cross-Origin Resource Sharing for the React SPA (and later the mobile app).
# Allowed origins come from FRONTEND_ORIGINS (comma-separated); defaults cover
# the local Vite dev server.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      ENV.fetch("FRONTEND_ORIGINS") { "http://localhost:5173,http://127.0.0.1:5173" }
        .split(",")
        .map(&:strip)
    )

    resource "*",
             headers: :any,
             expose: ["Authorization"],
             methods: %i[get post put patch delete options head]
  end
end
