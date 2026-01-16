#!/usr/bin/env python3
#Author: Srikanth Dabbiru d6falcon
"""
Abhimanyu CTF - Chakravyuha Challenge
Layer 1: Web Application Vulnerability (Local File Inclusion)
Layer 2: Docker Socket Escape

The Chakravyuha wheel formation analogy:
- Outer Ring: This vulnerable web app
- Middle Ring: Container escape/privilege escalation
- Inner Ring: Kubernetes/RBAC exploitation
- Core: Final flag in restricted area
"""

import os
import sys
import socket
import json
from flask import Flask, render_template, request, send_file, abort, jsonify
from pathlib import Path
import logging

try:
    import docker
    DOCKER_AVAILABLE = True
except ImportError:
    DOCKER_AVAILABLE = False

try:
    import redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False

try:
    import psycopg2
    from psycopg2 import sql
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False

app = Flask(__name__, template_folder='templates', static_folder='static')
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / 'uploads'
DOCUMENTS_DIR = BASE_DIR / 'documents'
CHALLENGE_DIR = BASE_DIR.parent / 'challenges'

# Flags are NO LONGER in environment variables to prevent leakage via LFI
# They are now computed dynamically based on actual exploitability
LAYER2_FLAG = 'CTF{ESCAPED_DOCKER_CONTAINER_LAYER2}'
LAYER3_FLAG = 'CTF{BREACHED_REDIS_AND_DATABASE_LAYER3}'

# Redis Configuration
REDIS_HOST = os.getenv('REDIS_HOST', 'chakravyuha-redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', 'ctf_redis_pass_123')

# PostgreSQL Configuration
PG_HOST = os.getenv('POSTGRES_HOST', 'chakravyuha-db')
PG_PORT = int(os.getenv('POSTGRES_PORT', 5432))
PG_DATABASE = os.getenv('POSTGRES_DB', 'ctf_db')
PG_USER = os.getenv('POSTGRES_USER', 'ctf_user')
PG_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'ctf_db_pass_456')

# Create directories if they don't exist
UPLOAD_DIR.mkdir(exist_ok=True)
DOCUMENTS_DIR.mkdir(exist_ok=True)
CHALLENGE_DIR.mkdir(exist_ok=True)


@app.route('/', methods=['GET'])
def index():
    """Welcome page - Introduces the Chakravyuha challenge"""
    return render_template('index.html', challenge_name='Chakravyuha')


@app.route('/documents', methods=['GET'])
def list_documents():
    """List available documents - VULNERABLE: No input validation"""
    try:
        documents = []
        if DOCUMENTS_DIR.exists():
            documents = [f.name for f in DOCUMENTS_DIR.iterdir() if f.is_file()]
        return render_template('documents.html', documents=documents)
    except Exception as e:
        logger.error(f"Error listing documents: {e}")
        return render_template('error.html', error="Error listing documents"), 500


@app.route('/view', methods=['GET'])
def view_file():
    """
    VULNERABLE ENDPOINT: Local File Inclusion (LFI)
    
    The vulnerability: No proper path validation or sanitization
    Attacker can use path traversal (../) to read arbitrary files
    
    Example exploits:
    - /view?file=../../../etc/passwd
    - /view?file=../../../../proc/self/environ
    - /view?file=../../../../etc/shadow (may fail due to permissions)
    """
    filename = request.args.get('file', '')
    
    if not filename:
        return render_template('error.html', error="No file specified"), 400
    
    # VULNERABILITY: Insufficient validation
    # This check only verifies the filename contains allowed chars, not the path
    if not all(c.isalnum() or c in '._/-' for c in filename):
        return render_template('error.html', error="Invalid filename"), 400
    
    # VULNERABLE: Using Path without proper canonicalization
    # Attacker can bypass the DOCUMENTS_DIR restriction using ../
    file_path = DOCUMENTS_DIR / filename
    
    try:
        resolved_path = file_path.resolve()
        
        # REMOVED: Boundary check that blocked LFI
        # Now allows true path traversal exploitation
        
        if not resolved_path.exists():
            abort(404)
        
        if resolved_path.is_dir():
            abort(403)
        
        # Serve the file - VULNERABLE to LFI
        logger.warning(f"[LAYER 1] Reading file via LFI: {resolved_path}")
        return send_file(resolved_path, as_attachment=False)
    
    except Exception as e:
        logger.error(f"File access error: {e}")
        abort(403)


@app.route('/api/read', methods=['POST'])
def api_read_file():
    """
    API endpoint with LFI vulnerability
    Demonstrates command injection risk
    """
    data = request.get_json() or {}
    filename = data.get('filename', '')
    
    if not filename:
        return {'error': 'No filename provided'}, 400
    
    # VULNERABLE: Direct file path construction
    file_path = DOCUMENTS_DIR / filename
    
    try:
        # Potential symlink attack vector
        with open(file_path, 'r') as f:
            content = f.read()
        return {'content': content, 'filename': filename}
    except FileNotFoundError:
        return {'error': 'File not found'}, 404
    except Exception as e:
        return {'error': str(e)}, 500


@app.route('/upload', methods=['GET', 'POST'])
def upload_file():
    """File upload endpoint - Can be used to write files for later exploitation"""
    if request.method == 'GET':
        return render_template('upload.html')
    
    if 'file' not in request.files:
        return render_template('error.html', error="No file provided"), 400
    
    file = request.files['file']
    if file.filename == '':
        return render_template('error.html', error="No file selected"), 400
    
    # VULNERABILITY: Insufficient filename validation
    # Could allow arbitrary file write with path traversal
    filename = file.filename
    
    # Weak validation
    if len(filename) > 255:
        return render_template('error.html', error="Filename too long"), 400
    
    try:
        file_path = UPLOAD_DIR / filename
        file.save(str(file_path))
        return render_template('upload_success.html', filename=filename)
    except Exception as e:
        logger.error(f"Upload error: {e}")
        return render_template('error.html', error="Upload failed"), 500


@app.route('/source', methods=['GET'])
def view_source():
    """Unintended: Allows viewing source code - aids in challenge solving"""
    source_file = BASE_DIR / 'app.py'
    try:
        with open(source_file, 'r') as f:
            content = f.read()
        return render_template('source.html', content=content)
    except Exception as e:
        return render_template('error.html', error="Cannot read source"), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for container orchestration"""
    return {'status': 'healthy', 'service': 'chakravyuha-layer1'}, 200


# ============================================
# LAYER 2: DOCKER SOCKET ESCAPE - EXPLOITABLE
# ============================================

@app.route('/docker-info', methods=['GET'])
def docker_info():
    """
    VULNERABLE ENDPOINT: Docker Socket Access
    
    Exploitation:
    GET /docker-info
    Returns container information accessible via docker socket
    Allows attacker to spawn privileged containers for escape
    """
    if not DOCKER_AVAILABLE:
        return jsonify({
            'status': 'error',
            'message': 'Docker library not available',
            'hint': 'Layer 2 requires docker-py library'
        }), 500
    
    try:
        # Connect to docker socket mounted in container
        client = docker.from_socket(unix_socket_path='/var/run/docker.sock')
        
        containers = client.containers.list()
        images = client.images.list()
        
        info = {
            'status': 'docker_socket_accessible',
            'layer': 2,
            'containers': [
                {
                    'id': c.id[:12],
                    'name': c.name,
                    'image': c.image.tags[0] if c.image.tags else 'unknown',
                    'status': c.status
                }
                for c in containers
            ],
            'images_count': len(images),
            'hint': 'Docker socket is accessible! You can spawn containers for privilege escalation.'
        }
        
        logger.info(f"Docker info accessed: {len(containers)} containers, {len(images)} images")
        return jsonify(info)
    
    except Exception as e:
        logger.error(f"Docker error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e),
            'hint': 'Docker socket may not be properly mounted or accessible'
        }), 500


@app.route('/layer2-flag', methods=['GET'])
def layer2_flag():
    """
    LAYER 2 FLAG ENDPOINT
    
    Accessible ONLY after proving docker socket access
    Flag is NOT stored in environment - it's computed dynamically
    Requires actual docker socket access to prove exploitation
    """
    if not DOCKER_AVAILABLE:
        return jsonify({
            'status': 'error',
            'message': 'Docker library not available'
        }), 403
    
    try:
        # CRITICAL: Verify docker socket access by attempting actual docker operations
        client = docker.from_socket(unix_socket_path='/var/run/docker.sock')
        client.ping()  # This will fail if socket is not accessible
        
        # Only return flag if docker socket is TRULY accessible
        logger.info("Layer 2 flag accessed - Docker socket verified")
        
        return jsonify({
            'status': 'layer2_complete',
            'flag': LAYER2_FLAG,  # Flag returned ONLY if docker socket works
            'message': 'You have successfully escaped the container!',
            'hint': 'You proved docker socket access by invoking the docker API',
            'next_layer': 'Access Redis service on port 6379 and PostgreSQL on port 5432 for Layer 3'
        })
    
    except Exception as e:
        logger.warning(f"Layer 2 flag access failed: {e}")
        return jsonify({
            'status': 'error',
            'message': 'Docker socket not accessible',
            'hint': 'Layer 2 requires container escape via docker socket access',
            'error_details': str(e)
        }), 403


@app.route('/system-info', methods=['GET'])
def system_info():
    """System information endpoint (Layer 2 reconnaissance)"""
    try:
        hostname = socket.gethostname()
        
        # Try to get docker socket access
        docker_accessible = False
        if DOCKER_AVAILABLE:
            try:
                client = docker.from_socket(unix_socket_path='/var/run/docker.sock')
                client.ping()
                docker_accessible = True
            except:
                docker_accessible = False
        
        # Get environment variables
        env_vars = {k: v for k, v in os.environ.items() if 'LAYER' in k or 'CTF' in k or 'FLAG' in k}
        
        info = {
            'hostname': hostname,
            'docker_socket_accessible': docker_accessible,
            'layer2_flag_available': LAYER2_FLAG != '',
            'environment_hints': env_vars,
            'capabilities': 'SYS_PTRACE, SYS_ADMIN',
            'hint': 'Check /docker-info and /layer2-flag endpoints for more information'
        }
        
        logger.info(f"System info accessed - Docker accessible: {docker_accessible}")
        return jsonify(info)
    
    except Exception as e:
        logger.error(f"System info error: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================
# LAYER 3: REDIS & DATABASE EXPLOITATION
# ============================================

@app.route('/redis-info', methods=['GET'])
def redis_info():
    """
    LAYER 3 ENDPOINT: Redis Service Information
    
    Exploitation:
    GET /redis-info
    Returns Redis connection details and hints
    """
    try:
        if not REDIS_AVAILABLE:
            return jsonify({
                'status': 'error',
                'message': 'Redis library not available',
                'hint': 'Layer 3 requires redis-py library'
            }), 500
        
        # Try to connect to Redis
        redis_client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=REDIS_PASSWORD,
            decode_responses=True
        )
        redis_client.ping()
        
        # Get Redis info
        info = redis_client.info()
        
        return jsonify({
            'status': 'redis_accessible',
            'layer': 3,
            'host': REDIS_HOST,
            'port': REDIS_PORT,
            'version': info.get('redis_version', 'unknown'),
            'connected_clients': info.get('connected_clients', 0),
            'used_memory': info.get('used_memory_human', 'unknown'),
            'hint': 'Redis is accessible! Try accessing /layer3-flag endpoint',
            'hint2': 'The password may be discoverable via Layer 1 LFI exploitation'
        })
    
    except Exception as e:
        logger.error(f"Redis info error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e),
            'hint': 'Redis may not be accessible. Try discovering credentials via Layer 1 LFI'
        }), 500


@app.route('/layer3-flag', methods=['GET'])
def layer3_flag():
    """
    LAYER 3 FLAG ENDPOINT: Redis Flag Retrieval
    
    IMPORTANT: Flag is NOT in environment variables
    Flag is computed dynamically only if Redis connection succeeds
    This prevents attackers from finding the flag via LFI in /proc/self/environ
    """
    if not REDIS_AVAILABLE:
        return jsonify({
            'status': 'error',
            'message': 'Redis library not available'
        }), 403
    
    try:
        # CRITICAL: Actually connect to Redis and verify access
        redis_client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=REDIS_PASSWORD,
            decode_responses=True,
            socket_connect_timeout=5
        )
        redis_client.ping()  # This will fail if credentials are wrong
        
        logger.info("Layer 3 Redis flag accessed - Redis verified")
        
        # Flag returned ONLY if Redis authentication succeeds
        return jsonify({
            'status': 'layer3_redis_complete',
            'flag': LAYER3_FLAG,
            'message': 'You have successfully breached Redis!',
            'hint': 'You proved Redis access by authenticating with correct credentials',
            'next_layer': 'Access PostgreSQL on port 5432 for database exploitation'
        })
    
    except Exception as e:
        logger.warning(f"Layer 3 flag access failed: {e}")
        return jsonify({
            'status': 'error',
            'message': 'Redis not accessible',
            'hint': 'Layer 3 requires access to Redis service with correct credentials',
            'error_details': str(e)
        }), 403


@app.route('/db-info', methods=['GET'])
def db_info():
    """
    LAYER 3 ENDPOINT: PostgreSQL Database Information
    
    Exploitation:
    GET /db-info
    Returns PostgreSQL connection details and hints
    """
    try:
        if not PSYCOPG2_AVAILABLE:
            return jsonify({
                'status': 'error',
                'message': 'PostgreSQL library not available',
                'hint': 'Layer 3 requires psycopg2 library'
            }), 500
        
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            database=PG_DATABASE,
            user=PG_USER,
            password=PG_PASSWORD
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()[0]
        
        cursor.execute("SELECT datname FROM pg_database WHERE datistemplate = false;")
        databases = [row[0] for row in cursor.fetchall()]
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'postgresql_accessible',
            'layer': 3,
            'host': PG_HOST,
            'port': PG_PORT,
            'database': PG_DATABASE,
            'user': PG_USER,
            'version': db_version,
            'databases': databases,
            'hint': 'PostgreSQL is accessible! Try accessing /layer3-db-flag endpoint',
            'hint2': 'Check if there are any exploitable SQL injection vectors'
        })
    
    except Exception as e:
        logger.error(f"PostgreSQL info error: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e),
            'hint': 'PostgreSQL may not be accessible. Try discovering credentials via Layer 1 LFI'
        }), 500


@app.route('/layer3-db-flag', methods=['GET'])
def layer3_db_flag():
    """
    LAYER 3 FLAG ENDPOINT: PostgreSQL Flag Retrieval
    
    Exploitation:
    GET /layer3-db-flag
    Retrieves Layer 3 flag from PostgreSQL
    """
    if not PSYCOPG2_AVAILABLE:
        return jsonify({
            'status': 'error',
            'message': 'PostgreSQL library not available'
        }), 403
    
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            database=PG_DATABASE,
            user=PG_USER,
            password=PG_PASSWORD
        )
        
        cursor = conn.cursor()
        
        # Query for flag from database (required, not optional)
        cursor.execute("SELECT flag FROM flags WHERE layer = 3 LIMIT 1;")
        result = cursor.fetchone()
        
        if not result:
            # Table exists but no Layer 3 flag found
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'error',
                'message': 'Layer 3 flag not found in database'
            }), 404
        
        flag = result[0]
        
        cursor.close()
        conn.close()
        
        logger.info("Layer 3 PostgreSQL flag accessed")
        
        return jsonify({
            'status': 'layer3_database_complete',
            'flag': flag,
            'message': 'You have successfully breached the PostgreSQL database!',
            'next_layer': 'Layer 4: Kubernetes RBAC Exploitation (requires K8s deployment)'
        })
    
    except Exception as e:
        logger.warning(f"Layer 3 database flag access failed: {e}")
        return jsonify({
            'status': 'error',
            'message': 'PostgreSQL not accessible',
            'hint': 'Layer 3 requires access to PostgreSQL with correct credentials'
        }), 403


@app.errorhandler(404)
def not_found(e):
    return render_template('error.html', error="Page not found"), 404


@app.errorhandler(500)
def server_error(e):
    return render_template('error.html', error="Internal server error"), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
