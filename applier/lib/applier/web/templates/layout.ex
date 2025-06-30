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
            .status-indicator { 
              display: inline-block; 
              width: 10px; 
              height: 10px; 
              border-radius: 50%; 
              margin-right: 5px; 
            }
            .status-processing { background-color: #ffa500; }
            .status-completed { background-color: #28a745; }
            .status-error { background-color: #dc3545; }
            .status-waiting_approval { background-color: #6c757d; }
            .live-status { font-size: 12px; color: #666; margin-left: 5px; }
            """
          end
          script do
            """
            // WebSocket connection for live updates
            let ws = null;
            let reconnectTimer = null;
            
            function connect() {
              const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
              const wsUrl = `${protocol}//${window.location.host}/ws`;
              
              ws = new WebSocket(wsUrl);
              
              ws.onopen = function() {
                console.log('WebSocket connected');
                clearTimeout(reconnectTimer);
              };
              
              ws.onmessage = function(event) {
                try {
                  const data = JSON.parse(event.data);
                  if (data.type === 'application_update') {
                    updateApplicationStatus(data.application_id, data.status, data.message);
                  }
                } catch (e) {
                  console.error('Error parsing WebSocket message:', e);
                }
              };
              
              ws.onclose = function() {
                console.log('WebSocket disconnected, attempting to reconnect...');
                reconnectTimer = setTimeout(connect, 3000);
              };
              
              ws.onerror = function(error) {
                console.error('WebSocket error:', error);
              };
            }
            
            function updateApplicationStatus(applicationId, status, message) {
              const rows = document.querySelectorAll('tr[data-app-id="' + applicationId + '"]');
              rows.forEach(row => {
                const statusCell = row.querySelector('.live-status-cell');
                if (statusCell) {
                  statusCell.innerHTML = `
                    <span class="status-indicator status-${status}"></span>
                    <span class="live-status">${message}</span>
                  `;
                }
              });
            }
            
            // Connect when page loads
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', connect);
            } else {
              connect();
            }
            """
          end
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
