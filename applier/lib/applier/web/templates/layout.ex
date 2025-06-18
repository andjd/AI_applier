defmodule Applier.Web.Templates.Layout do
  use Temple.Component

  def app(assigns) do
    page_title = Map.get(assigns, :title, "Job Applications")
    
    temple do
      "<!DOCTYPE html>"
      html do
        head do
          title do
            page_title
          end
          style do
            """
            body { font-family: Arial, sans-serif; margin: 40px; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
            .status-true { color: green; font-weight: bold; }
            .status-false { color: #999; }
            .nav { margin-bottom: 20px; }
            .nav a { margin-right: 15px; text-decoration: none; color: #007cba; }
            .nav a:hover { text-decoration: underline; }
            .form-group { margin-bottom: 15px; }
            label { display: block; margin-bottom: 5px; font-weight: bold; }
            input[type="text"], input[type="url"], textarea { 
                width: 100%; 
                padding: 8px; 
                border: 1px solid #ddd; 
                border-radius: 4px; 
                font-size: 14px;
            }
            textarea { height: 150px; resize: vertical; }
            button { 
                background-color: #007cba; 
                color: white; 
                padding: 10px 20px; 
                border: none; 
                border-radius: 4px; 
                cursor: pointer;
                font-size: 14px;
            }
            button:hover { background-color: #005a87; }
            .help { color: #666; font-size: 12px; margin-top: 5px; }
            .error { color: red; margin-bottom: 20px; padding: 10px; border: 1px solid red; background-color: #ffe6e6; }
            """
          end
        end
        body do
          div class: "nav" do
            a href: "/", do: "Applications"
            a href: "/add", do: "Add Application"
          end
          
          slot :default
        end
      end
    end
  end
end