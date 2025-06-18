defmodule Applier.Web.Router do
  use Plug.Router
  alias Applier.Web.Templates.Applications

  plug Plug.Static, at: "/", from: :applier
  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :dispatch

  get "/" do
    applications = Applier.Applications.list_applications()
    
    html = Applications.index(%{applications: applications})
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/add" do
    html = Applications.add(%{})
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  post "/add" do
    case Applier.Applications.create_application(conn.params) do
      {:ok, _application} ->
        conn
        |> put_resp_header("location", "/")
        |> send_resp(302, "")
      
      {:error, changeset} ->
        errors = Enum.map(changeset.errors, fn {field, {message, _}} ->
          "#{field}: #{message}"
        end) |> Enum.join(", ")
        
        html = Applications.error(%{errors: errors})
        
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, html)
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end