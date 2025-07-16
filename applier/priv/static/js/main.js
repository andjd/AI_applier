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
    
    // Update application state and action buttons based on status
    updateApplicationStateFromWebSocket(row, status);
  });
}

function updateApplicationStateFromWebSocket(row, status) {
  // Get current application state from the row
  const app = extractApplicationStateFromRow(row);
  
  // Update application state based on WebSocket status
  switch (status) {
    case 'parsed':
      app.parsed = true;
      break;
    case 'docs_generated':
      app.docs_generated = true;
      break;
    case 'form_filled':
      app.form_filled = true;
      break;
    case 'completed':
      app.submitted = true;
      break;
    case 'error':
      app.errors = true;
      break;
    // For status updates that don't directly map to state changes,
    // we can infer state from the current status
    case 'processing':
      // Application is being processed, no state change needed
      break;
    case 'generating_docs':
      // Docs are being generated, application must be approved
      app.approved = true;
      break;
    case 'filling_form':
      // Form is being filled, docs must be generated
      app.docs_generated = true;
      break;
    case 'completing':
      // Application is being marked complete, form must be filled
      app.form_filled = true;
      break;
    case 'waiting_approval':
      // Application is waiting for approval, must be parsed
      app.parsed = true;
      break;
  }
  
  // Update the status indicators in the row
  updateStatusIndicators(row, app);
  
  // Update action buttons
  const actionCell = row.querySelector('td:last-child');
  if (actionCell) {
    actionCell.innerHTML = generateActionButtons(app);
  }
}

function extractApplicationStateFromRow(row) {
  // Extract current application state from the row's status indicators
  const app = {
    id: row.dataset.appId,
    parsed: row.querySelector('td:nth-child(8) span').textContent.trim() === '✓',
    approved: row.querySelector('td:nth-child(9) span').textContent.trim() === '✓',
    docs_generated: row.querySelector('td:nth-child(10) span').textContent.trim() === '✓',
    form_filled: row.querySelector('td:nth-child(11) span').textContent.trim() === '✓',
    submitted: row.querySelector('td:nth-child(12) span').textContent.trim() === '✓',
    errors: false // Will be set based on status
  };
  return app;
}

function updateStatusIndicators(row, app) {
  const statusMapping = {
    'parsed': { index: 8, value: app.parsed },
    'approved': { index: 9, value: app.approved },
    'docs_generated': { index: 10, value: app.docs_generated },
    'form_filled': { index: 11, value: app.form_filled },
    'submitted': { index: 12, value: app.submitted }
  };
  
  Object.keys(statusMapping).forEach(status => {
    const { index, value } = statusMapping[status];
    const cell = row.querySelector(`td:nth-child(${index}) span`);
    if (cell) {
      cell.className = `status-${value}`;
      cell.innerHTML = value ? '✓' : '○';
    }
  });
}

// Connect when page loads
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', connect);
} else {
  connect();
}

// Confirmation dialog for reject actions
function confirmReject(companyName, jobTitle) {
  let message = `Are you sure you want to reject the application`;
  if (companyName && companyName !== 'this application') {
    message += ` for ${companyName}`;
    if (jobTitle) {
      message += ` (${jobTitle})`;
    }
  }
  message += `?\n\nRejected applications will be hidden from the main dashboard but can be viewed in the Rejected filter.`;
  
  return confirm(message);
}

// AJAX helper function
function makeAjaxCall(url, button, confirmMessage) {
  if (confirmMessage && !confirm(confirmMessage)) {
    return;
  }
  
  // Set button to loading state
  const originalText = button.textContent;
  button.disabled = true;
  button.textContent = 'Processing...';
  
  fetch(url, {
    method: 'POST',
    headers: {
      'X-Requested-With': 'XMLHttpRequest',
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      // Update the application row with new data
      updateApplicationRow(data.application);
      showMessage(data.message, 'success');
    } else {
      showMessage(data.message, 'error');
    }
  })
  .catch(error => {
    console.error('Error:', error);
    showMessage('An error occurred. Please try again.', 'error');
  })
  .finally(() => {
    // Reset button state
    button.disabled = false;
    button.textContent = originalText;
  });
}

// Update application row with new data
function updateApplicationRow(application) {
  const row = document.querySelector(`tr[data-app-id="${application.id}"]`);
  if (!row) return;
  
  // Update status indicators
  const statusMapping = {
    'parsed': application.parsed,
    'approved': application.approved,
    'docs_generated': application.docs_generated,
    'form_filled': application.form_filled,
    'submitted': application.submitted
  };
  
  Object.keys(statusMapping).forEach(status => {
    const cell = row.querySelector(`td:nth-child(${getStatusColumnIndex(status)}) span`);
    if (cell) {
      cell.className = `status-${statusMapping[status]}`;
      cell.innerHTML = statusMapping[status] ? '✓' : '○';
    }
  });
  
  // Update action buttons
  const actionCell = row.querySelector('td:last-child');
  if (actionCell) {
    actionCell.innerHTML = generateActionButtons(application);
  }
}

// Get column index for status updates
function getStatusColumnIndex(status) {
  const mapping = {
    'parsed': 8,
    'approved': 9,
    'docs_generated': 10,
    'form_filled': 11,
    'submitted': 12
  };
  return mapping[status] || 0;
}

// Generate action buttons HTML
function generateActionButtons(app) {
  let html = '<div style="display: flex; gap: 5px;">';
  
  if (!app.parsed) {
    html += '<button class="btn btn-secondary" disabled>Processing...</button>';
  } else if (!app.approved) {
    html += '<button class="btn btn-primary" onclick="makeAjaxCall(\'/applications/' + app.id + '/approve\', this)">Approve</button>';
    html += '<button class="btn btn-warning" onclick="makeAjaxCall(\'/applications/' + app.id + '/priority\', this)">Priority</button>';
  } else if (app.approved && !app.docs_generated) {
    html += '<button class="btn btn-secondary" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Generate Docs</button>';
  } else if (app.docs_generated && !app.form_filled) {
    html += '<button class="btn btn-secondary" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Fill Form</button>';
  } else if (app.form_filled && !app.submitted) {
    html += '<button class="btn btn-secondary" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Fill Form</button>';
    html += '<button class="btn btn-success" onclick="makeAjaxCall(\'/applications/' + app.id + '/complete\', this)">Mark Complete</button>';
  } else if (app.submitted) {
    html += '<button class="btn btn-secondary" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Fill Form</button>';
  } else if (app.errors) {
    html += '<button class="btn btn-warning" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Retry</button>';
  } else {
    html += '<button class="btn btn-secondary" onclick="makeAjaxCall(\'/applications/' + app.id + '/retry\', this)">Continue</button>';
  }
  
  // Always add reject button
  html += '<button class="btn btn-danger" onclick="handleReject(' + app.id + ', this)">Reject</button>';
  html += '</div>';
  
  return html;
}

// Handle reject action with confirmation
function handleReject(applicationId, button) {
  makeAjaxCall('/applications/' + applicationId + '/reject', button);
}

// Create reject confirmation message
function createRejectConfirmMessage(companyName, jobTitle) {
  let message = 'Are you sure you want to reject the application';
  if (companyName && companyName !== '-') {
    message += ' for ' + companyName;
    if (jobTitle && jobTitle !== '-') {
      message += ' (' + jobTitle + ')';
    }
  }
  message += '?\n\nRejected applications will be hidden from the main dashboard but can be viewed in the Rejected filter.';
  return message;
}

// Show success/error messages
function showMessage(message, type) {
  // Remove any existing messages
  const existingMessage = document.querySelector('.ajax-message');
  if (existingMessage) {
    existingMessage.remove();
  }
  
  // Create new message
  const messageDiv = document.createElement('div');
  messageDiv.className = `ajax-message alert alert-${type}`;
  messageDiv.textContent = message;
  messageDiv.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    padding: 10px 20px;
    border-radius: 4px;
    font-weight: bold;
    z-index: 1000;
    max-width: 300px;
    ${type === 'success' ? 'background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb;' : 'background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb;'}
  `;
  
  document.body.appendChild(messageDiv);
  
  // Remove message after 3 seconds
  setTimeout(() => {
    messageDiv.remove();
  }, 3000);
}

// Handle fetch jobs button
function fetchJobs(button) {
  // Set button to loading state
  const originalText = button.textContent;
  button.disabled = true;
  button.textContent = 'Fetching...';
  
  fetch('/fetch-jobs', {
    method: 'POST',
    headers: {
      'X-Requested-With': 'XMLHttpRequest',
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      showMessage(data.message, 'success');
      // Optionally reload the page to show new jobs
      setTimeout(() => {
        window.location.reload();
      }, 2000);
    } else {
      showMessage(data.message, 'error');
    }
  })
  .catch(error => {
    console.error('Error:', error);
    showMessage('An error occurred while fetching jobs. Please try again.', 'error');
  })
  .finally(() => {
    // Reset button state
    button.disabled = false;
    button.textContent = originalText;
  });
}

// Copy to clipboard functionality
function copyToClipboard(elementId, button) {
  const element = document.getElementById(elementId);
  if (!element) {
    console.error('Element not found:', elementId);
    return;
  }
  
  const text = element.textContent || element.innerText;
  
  if (navigator.clipboard && window.isSecureContext) {
    // Use modern clipboard API
    navigator.clipboard.writeText(text).then(() => {
      showCopySuccess(button);
    }).catch(err => {
      console.error('Failed to copy text: ', err);
      fallbackCopyTextToClipboard(text, button);
    });
  } else {
    // Fallback for older browsers
    fallbackCopyTextToClipboard(text, button);
  }
}

function fallbackCopyTextToClipboard(text, button) {
  const textArea = document.createElement("textarea");
  textArea.value = text;
  
  // Avoid scrolling to bottom
  textArea.style.top = "0";
  textArea.style.left = "0";
  textArea.style.position = "fixed";
  
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();
  
  try {
    const successful = document.execCommand('copy');
    if (successful) {
      showCopySuccess(button);
    } else {
      console.error('Fallback copy failed');
    }
  } catch (err) {
    console.error('Fallback copy failed', err);
  }
  
  document.body.removeChild(textArea);
}

function showCopySuccess(button) {
  const originalText = button.textContent;
  button.textContent = '✓ Copied!';
  button.classList.add('copied');
  
  setTimeout(() => {
    button.textContent = originalText;
    button.classList.remove('copied');
  }, 2000);
}