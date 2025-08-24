from flask import Flask, render_template, request, jsonify, redirect, url_for, flash, session
import json
import os
from datetime import datetime, timedelta
import uuid

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-here')

# Простая файловая база данных
DATA_FILE = 'data.json'

def load_data():
    """Загрузка данных из файла"""
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {'users': [], 'messages': [], 'tasks': []}

def save_data(data):
    """Сохранение данных в файл"""
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_user_by_username(username):
    """Поиск пользователя по имени"""
    data = load_data()
    for user in data['users']:
        if user['username'] == username:
            return user
    return None

def get_user_by_id(user_id):
    """Поиск пользователя по ID"""
    data = load_data()
    for user in data['users']:
        if user['id'] == user_id:
            return user
    return None

def get_tasks_by_user(user_id):
    """Получение задач пользователя"""
    data = load_data()
    my_tasks = [task for task in data['tasks'] if task.get('assigned_to') == user_id]
    created_tasks = [task for task in data['tasks'] if task.get('created_by') == user_id]
    
    # Добавляем имена создателей
    for task in my_tasks + created_tasks:
        creator = get_user_by_id(task.get('created_by'))
        if creator:
            task['creator_name'] = creator['username']
        else:
            task['creator_name'] = 'Неизвестный'
    
    return my_tasks, created_tasks

def get_messages_by_room(room):
    """Получение сообщений комнаты"""
    data = load_data()
    messages = [msg for msg in data['messages'] if msg['room'] == room]
    # Добавляем информацию о пользователях
    for msg in messages:
        user = get_user_by_id(msg['sender_id'])
        if user:
            msg['sender_name'] = user['username']
    return messages

# Маршруты
@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        user = get_user_by_username(username)
        if user and user['password'] == password:
            session['user_id'] = user['id']
            session['username'] = user['username']
            return redirect(url_for('dashboard'))
        else:
            flash('Неверное имя пользователя или пароль')
    
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        email = request.form['email']
        
        if get_user_by_username(username):
            flash('Пользователь с таким именем уже существует')
            return render_template('register.html')
        
        data = load_data()
        new_user = {
            'id': str(uuid.uuid4()),
            'username': username,
            'password': password,
            'email': email,
            'created_at': datetime.now().isoformat()
        }
        data['users'].append(new_user)
        save_data(data)
        
        flash('Регистрация успешна! Теперь вы можете войти.')
        return redirect(url_for('login'))
    
    return render_template('register.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    my_tasks, _ = get_tasks_by_user(session['user_id'])
    return render_template('dashboard.html', tasks=my_tasks)

@app.route('/chat/<room>')
def chat(room):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    messages = get_messages_by_room(room)
    return render_template('chat.html', room=room, messages=messages)

@app.route('/tasks')
def tasks():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    my_tasks, created_tasks = get_tasks_by_user(session['user_id'])
    return render_template('tasks.html', my_tasks=my_tasks, created_tasks=created_tasks)

@app.route('/create_task', methods=['POST'])
def create_task():
    if 'user_id' not in session:
        return jsonify({'success': False, 'error': 'Не авторизован'})
    
    data = request.get_json()
    task = {
        'id': str(uuid.uuid4()),
        'title': data['title'],
        'description': data.get('description', ''),
        'due_date': data['due_date'],
        'created_by': session['user_id'],
        'assigned_to': data.get('assigned_to'),
        'status': 'pending',
        'created_at': datetime.now().isoformat()
    }
    
    db_data = load_data()
    db_data['tasks'].append(task)
    save_data(db_data)
    
    return jsonify({'success': True, 'task_id': task['id']})

@app.route('/send_message', methods=['POST'])
def send_message():
    if 'user_id' not in session:
        return jsonify({'success': False, 'error': 'Не авторизован'})
    
    data = request.get_json()
    message = {
        'id': str(uuid.uuid4()),
        'content': data['message'],
        'sender_id': session['user_id'],
        'room': data['room'],
        'timestamp': datetime.now().isoformat()
    }
    
    db_data = load_data()
    db_data['messages'].append(message)
    save_data(db_data)
    
    return jsonify({'success': True, 'message_id': message['id']})

@app.route('/get_messages/<room>')
def get_messages(room):
    if 'user_id' not in session:
        return jsonify({'success': False, 'error': 'Не авторизован'})
    
    messages = get_messages_by_room(room)
    return jsonify({'success': True, 'messages': messages})

@app.route('/get_users')
def get_users():
    if 'user_id' not in session:
        return jsonify({'success': False, 'error': 'Не авторизован'})
    
    data = load_data()
    users = [{'id': user['id'], 'username': user['username']} for user in data['users']]
    return jsonify({'success': True, 'users': users})

# Контекстный процессор для шаблонов
@app.context_processor
def inject_user():
    """Добавляет информацию о пользователе в шаблоны"""
    if 'user_id' in session:
        user = get_user_by_id(session['user_id'])
        return {'current_user': user}
    return {'current_user': None}

if __name__ == '__main__':
    # Создаем файл данных, если его нет
    if not os.path.exists(DATA_FILE):
        save_data({'users': [], 'messages': [], 'tasks': []})
    
    print("🚀 Запуск PESCO/CC7 WAREHOUSE TEAM...")
    print("📱 Откройте браузер и перейдите по адресу: http://localhost:5002")
    print("👤 Для начала работы зарегистрируйтесь или войдите в систему")
    
    # Получаем порт из переменной окружения (для Heroku) или используем 5002
    port = int(os.environ.get('PORT', 5002))
    app.run(debug=False, host='0.0.0.0', port=port)
