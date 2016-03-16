# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
 # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
 # Rails.application.config.assets.precompile += %w( search.js )
#TODO: remove this hack:
#(Rails complains about the assets without this, but manually listing them is a bad idea.)
Rails.application.config.assets.precompile += %w( list.css filter.css graphs.css filter.js filter_form.js graph.js )

