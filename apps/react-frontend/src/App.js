import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [apiData, setApiData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await axios.get('/api/health');
        setApiData(response.data);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>🚀 Kubernetes Homelab</h1>
        <p>React Frontend Application</p>
        
        <div className="status-section">
          <h2>API Status</h2>
          {loading && <p>Loading...</p>}
          {error && <p className="error">Error: {error}</p>}
          {apiData && (
            <div className="api-info">
              <p><strong>Status:</strong> {apiData.status}</p>
              <p><strong>Message:</strong> {apiData.message}</p>
              <p><strong>Timestamp:</strong> {apiData.timestamp}</p>
              <p><strong>Version:</strong> {apiData.version}</p>
            </div>
          )}
        </div>

        <div className="services-section">
          <h2>Available Services</h2>
          <div className="service-grid">
            <div className="service-card">
              <h3>📊 Grafana</h3>
              <p>Monitoring & Dashboards</p>
            </div>
            <div className="service-card">
              <h3>🔍 Prometheus</h3>
              <p>Metrics Collection</p>
            </div>
            <div className="service-card">
              <h3>🐘 PostgreSQL</h3>
              <p>Database</p>
            </div>
            <div className="service-card">
              <h3>🔴 Redis</h3>
              <p>Cache & Sessions</p>
            </div>
            <div className="service-card">
              <h3>🐰 RabbitMQ</h3>
              <p>Message Queue</p>
            </div>
            <div className="service-card">
              <h3>🔄 ArgoCD</h3>
              <p>GitOps Deployment</p>
            </div>
          </div>
        </div>
      </header>
    </div>
  );
}

export default App;
