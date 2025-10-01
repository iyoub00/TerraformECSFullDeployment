

import os
import logging
from datetime import datetime
from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configuration
PORT = int(os.getenv('PORT', 8000))
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
VERSION = '1.0.0'


@app.before_request
def log_request():
    """Log incoming requests"""
    logger.info(f"{request.method} {request.path} from {request.remote_addr}")


@app.after_request
def add_headers(response):
    """Add security and CORS headers"""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Access-Control-Allow-Origin'] = '*'
    return response


@app.route('/')
def root():
    """Root endpoint"""
    return jsonify({
        'message': 'Hello from ECS Fargate with Python Flask!',
        'environment': ENVIRONMENT,
        'version': VERSION,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })


@app.route('/health')
def health():
    """Health check endpoint for ALB"""
    return jsonify({
        'status': 'healthy',
        'environment': ENVIRONMENT,
        'version': VERSION,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }), 200


@app.route('/api/info')
def info():
    """API information endpoint"""
    return jsonify({
        'service': 'ECS Fargate Application',
        'language': 'Python',
        'framework': 'Flask',
        'version': VERSION,
        'environment': ENVIRONMENT,
        'endpoints': {
            '/': 'Root endpoint',
            '/health': 'Health check',
            '/api/info': 'API information',
            '/api/echo': 'Echo endpoint (POST)'
        }
    })


@app.route('/api/echo', methods=['POST'])
def echo():
    """Echo endpoint for testing"""
    data = request.get_json()
    return jsonify({
        'received': data,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    })


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Not Found',
        'path': request.path,
        'method': request.method
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'error': 'Internal Server Error'
    }), 500


if __name__ == '__main__':
    logger.info(f"Starting Flask server on port {PORT} in {ENVIRONMENT} environment")
    logger.info(f"Version: {VERSION}")

    # For development only - use Gunicorn in production
    app.run(
        host='0.0.0.0',
        port=PORT,
        debug=(ENVIRONMENT == 'development')
    )