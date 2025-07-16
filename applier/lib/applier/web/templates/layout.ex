defmodule Applier.Web.Templates.Layout do
  alias ElixirLS.LanguageServer.Plugins.Phoenix
  use Temple.Component

  def app(assigns) do

    temple do
      "<!DOCTYPE html>"
      html do
        head do
          title do
            @title
          end
          link rel: "stylesheet", href: "/static/css/main.css"
          script src: "/static/js/main.js"
        end
        body do
          div class: "nav" do
            a href: "/", do: "Applications"
            a href: "/add", do: "Add Application"
          end

          slot @inner_block
        end
      end
    end
  end
end
