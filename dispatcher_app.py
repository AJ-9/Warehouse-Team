from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, date, time
import os
import pandas as pd
from io import BytesIO
import base64
import secrets
from functools import wraps

app = Flask(__name__)

# Конфигурация для продакшена и разработки
if os.environ.get('DATABASE_URL'):
    # Продакшен - используем PostgreSQL
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL').replace('postgres://', 'postgresql://')
else:
    # Разработка - используем SQLite
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///dispatcher.db'

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', secrets.token_hex(16))
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Базовые настройки безопасности
app.config['SESSION_COOKIE_SECURE'] = os.environ.get('FLASK_ENV') == 'production'
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'

db = SQLAlchemy(app)

class VehicleRecord(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    location = db.Column(db.String(200), nullable=False)  # Локация (место выгрузки)
    vehicle_number = db.Column(db.String(50), nullable=False)  # Номер транспортного средства
    queue_order = db.Column(db.Integer)  # Очередность
    status = db.Column(db.String(50), nullable=False)  # Статус
    driver_name = db.Column(db.String(100), nullable=False)  # ФИО водителя
    phone = db.Column(db.String(20))  # Телефон
    supplier = db.Column(db.String(100))  # Поставщик
    title = db.Column(db.String(200))  # Титул
    arrival_date = db.Column(db.Date)  # Дата прибытия
    arrival_time = db.Column(db.Time)  # Время прибытия
    departure_date = db.Column(db.Date)  # Дата убытия
    departure_time = db.Column(db.Time)  # Время убытия
    tn_number = db.Column(db.String(50))  # Номер ТН
    comments = db.Column(db.Text)  # Комментарии
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'location': self.location,
            'vehicle_number': self.vehicle_number,
            'queue_order': self.queue_order,
            'status': self.status,
            'driver_name': self.driver_name,
            'phone': self.phone,
            'supplier': self.supplier,
            'title': self.title,
            'arrival_date': self.arrival_date.strftime('%Y-%m-%d') if self.arrival_date else None,
            'arrival_time': self.arrival_time.strftime('%H:%M') if self.arrival_time else None,
            'departure_date': self.departure_date.strftime('%Y-%m-%d') if self.departure_date else None,
            'departure_time': self.departure_time.strftime('%H:%M') if self.departure_time else None,
            'tn_number': self.tn_number,
            'comments': self.comments,
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'updated_at': self.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        }

# Статусы для выпадающего списка
STATUS_OPTIONS = [
    'на складе в очереди',
    'покинул склад',
    'ПАД-4',
    'в пути',
    'за забором в очереди',
    'КПП-6'
]

# Простая аутентификация
ADMIN_USERNAME = os.environ.get('ADMIN_USERNAME', 'admin')
ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'dispatcher2024')

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session['logged_in'] = True
            flash('Вы успешно вошли в систему!', 'success')
            return redirect(url_for('index'))
        else:
            flash('Неверное имя пользователя или пароль!', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    flash('Вы вышли из системы!', 'info')
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    records = VehicleRecord.query.order_by(VehicleRecord.created_at.desc()).all()
    return render_template('index.html', records=records, status_options=STATUS_OPTIONS)

@app.route('/add', methods=['GET', 'POST'])
@login_required
def add_record():
    if request.method == 'POST':
        try:
            # Получаем данные из формы
            arrival_date = None
            arrival_time = None
            departure_date = None
            departure_time = None
            
            if request.form.get('arrival_date'):
                arrival_date = datetime.strptime(request.form['arrival_date'], '%Y-%m-%d').date()
            if request.form.get('arrival_time'):
                arrival_time = datetime.strptime(request.form['arrival_time'], '%H:%M').time()
            if request.form.get('departure_date'):
                departure_date = datetime.strptime(request.form['departure_date'], '%Y-%m-%d').date()
            if request.form.get('departure_time'):
                departure_time = datetime.strptime(request.form['departure_time'], '%H:%M').time()
            
            record = VehicleRecord(
                location=request.form['location'],
                vehicle_number=request.form['vehicle_number'],
                queue_order=int(request.form['queue_order']) if request.form.get('queue_order') else None,
                status=request.form['status'],
                driver_name=request.form['driver_name'],
                phone=request.form.get('phone'),
                supplier=request.form.get('supplier'),
                title=request.form.get('title'),
                arrival_date=arrival_date,
                arrival_time=arrival_time,
                departure_date=departure_date,
                departure_time=departure_time,
                tn_number=request.form.get('tn_number'),
                comments=request.form.get('comments')
            )
            
            db.session.add(record)
            db.session.commit()
            flash('Запись успешно добавлена!', 'success')
            return redirect(url_for('index'))
        except Exception as e:
            flash(f'Ошибка при добавлении записи: {str(e)}', 'error')
            db.session.rollback()
    
    return render_template('add_record.html', status_options=STATUS_OPTIONS)

@app.route('/edit/<int:id>', methods=['GET', 'POST'])
@login_required
def edit_record(id):
    record = VehicleRecord.query.get_or_404(id)
    
    if request.method == 'POST':
        try:
            # Обновляем данные
            record.location = request.form['location']
            record.vehicle_number = request.form['vehicle_number']
            record.queue_order = int(request.form['queue_order']) if request.form.get('queue_order') else None
            record.status = request.form['status']
            record.driver_name = request.form['driver_name']
            record.phone = request.form.get('phone')
            record.supplier = request.form.get('supplier')
            record.title = request.form.get('title')
            record.tn_number = request.form.get('tn_number')
            record.comments = request.form.get('comments')
            
            # Обрабатываем даты и время
            if request.form.get('arrival_date'):
                record.arrival_date = datetime.strptime(request.form['arrival_date'], '%Y-%m-%d').date()
            else:
                record.arrival_date = None
                
            if request.form.get('arrival_time'):
                record.arrival_time = datetime.strptime(request.form['arrival_time'], '%H:%M').time()
            else:
                record.arrival_time = None
                
            if request.form.get('departure_date'):
                record.departure_date = datetime.strptime(request.form['departure_date'], '%Y-%m-%d').date()
            else:
                record.departure_date = None
                
            if request.form.get('departure_time'):
                record.departure_time = datetime.strptime(request.form['departure_time'], '%H:%M').time()
            else:
                record.departure_time = None
            
            record.updated_at = datetime.utcnow()
            db.session.commit()
            flash('Запись успешно обновлена!', 'success')
            return redirect(url_for('index'))
        except Exception as e:
            flash(f'Ошибка при обновлении записи: {str(e)}', 'error')
            db.session.rollback()
    
    return render_template('edit_record.html', record=record, status_options=STATUS_OPTIONS)

@app.route('/delete/<int:id>')
@login_required
def delete_record(id):
    try:
        record = VehicleRecord.query.get_or_404(id)
        db.session.delete(record)
        db.session.commit()
        flash('Запись успешно удалена!', 'success')
    except Exception as e:
        flash(f'Ошибка при удалении записи: {str(e)}', 'error')
        db.session.rollback()
    
    return redirect(url_for('index'))

@app.route('/export_excel')
@login_required
def export_excel():
    try:
        records = VehicleRecord.query.all()
        
        # Создаем DataFrame
        data = []
        for record in records:
            data.append({
                'ID': record.id,
                'Локация': record.location,
                'Номер ТС': record.vehicle_number,
                'Очередность': record.queue_order,
                'Статус': record.status,
                'ФИО водителя': record.driver_name,
                'Телефон': record.phone,
                'Поставщик': record.supplier,
                'Титул': record.title,
                'Дата прибытия': record.arrival_date.strftime('%Y-%m-%d') if record.arrival_date else '',
                'Время прибытия': record.arrival_time.strftime('%H:%M') if record.arrival_time else '',
                'Дата убытия': record.departure_date.strftime('%Y-%m-%d') if record.departure_date else '',
                'Время убытия': record.departure_time.strftime('%H:%M') if record.departure_time else '',
                'Номер ТН': record.tn_number,
                'Комментарии': record.comments,
                'Создано': record.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'Обновлено': record.updated_at.strftime('%Y-%m-%d %H:%M:%S')
            })
        
        df = pd.DataFrame(data)
        
        # Создаем Excel файл в памяти
        output = BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Диспетчерская', index=False)
        
        output.seek(0)
        
        # Возвращаем файл как ответ
        from flask import make_response
        response = make_response(output.getvalue())
        response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        response.headers['Content-Disposition'] = f'attachment; filename=dispatcher_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
        
        return response
        
    except Exception as e:
        flash(f'Ошибка при экспорте: {str(e)}', 'error')
        return redirect(url_for('index'))

@app.route('/api/records')
@login_required
def api_records():
    records = VehicleRecord.query.all()
    return jsonify([record.to_dict() for record in records])

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    
    # Настройки для продакшена
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') != 'production'
    
    app.run(debug=debug, host='0.0.0.0', port=port)