import Config

# Configure ExSync for hot reloading in development
config :exsync,
  reload_timeout: 75,
  reload_callback: {ExSync, :code_reload_callback, []}