# Rails 8 loads routes lazily outside eager_load (development, test): the
# first url helper call draws them. A Solid Queue worker is its own process,
# so it starts without routes, and two jobs rendering at once (the card
# broadcast of a two-file upload) raced the drawing — one failed with
# "undefined method 'arquivo_path'" and its file stayed "failed" (seen
# 05/10/2026, Etapa 1.2 2/3). Draw them once when the worker starts.
SolidQueue.on_worker_start { Rails.application.reload_routes_unless_loaded }
