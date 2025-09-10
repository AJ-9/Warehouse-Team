#!/usr/bin/env python3
"""
Скрипт для быстрого тестирования диспетчерской системы локально
"""

import os
import sys
import subprocess

def check_python_version():
    """Проверяет версию Python"""
    if sys.version_info < (3, 7):
        print("❌ Требуется Python 3.7 или выше")
        return False
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
    return True

def install_requirements():
    """Устанавливает зависимости"""
    try:
        print("📦 Устанавливаем зависимости...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ Зависимости установлены")
        return True
    except subprocess.CalledProcessError:
        print("❌ Ошибка при установке зависимостей")
        return False

def create_env_file():
    """Создает файл .env если его нет"""
    if not os.path.exists('.env'):
        print("🔧 Создаем файл .env...")
        with open('.env', 'w') as f:
            f.write("""# Локальная конфигурация
SECRET_KEY=local-development-secret-key-12345
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
FLASK_ENV=development
PORT=5000
""")
        print("✅ Файл .env создан")
        print("🔑 Данные для входа: admin / admin123")
    else:
        print("✅ Файл .env уже существует")

def run_app():
    """Запускает приложение"""
    print("🚀 Запускаем приложение...")
    print("📱 Приложение будет доступно по адресу: http://localhost:5000")
    print("🔑 Данные для входа: admin / admin123")
    print("⏹️  Для остановки нажмите Ctrl+C")
    print("-" * 50)
    
    try:
        subprocess.run([sys.executable, "dispatcher_app.py"])
    except KeyboardInterrupt:
        print("\n👋 Приложение остановлено")

def main():
    """Основная функция"""
    print("🚛 Диспетчерская система - Локальный тест")
    print("=" * 50)
    
    # Проверяем версию Python
    if not check_python_version():
        return
    
    # Устанавливаем зависимости
    if not install_requirements():
        return
    
    # Создаем файл .env
    create_env_file()
    
    # Запускаем приложение
    run_app()

if __name__ == "__main__":
    main()