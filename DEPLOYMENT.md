# 🚀 Развертывание диспетчерской системы в облаке

## Варианты развертывания

### 1. Heroku (Рекомендуется - бесплатно)

#### Шаг 1: Подготовка
1. Создайте аккаунт на [Heroku](https://heroku.com)
2. Установите [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)

#### Шаг 2: Создание приложения
```bash
# Войдите в Heroku
heroku login

# Создайте новое приложение
heroku create your-dispatcher-app-name

# Добавьте PostgreSQL базу данных
heroku addons:create heroku-postgresql:mini
```

#### Шаг 3: Настройка переменных окружения
```bash
# Установите секретный ключ
heroku config:set SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(16))")

# Установите учетные данные администратора
heroku config:set ADMIN_USERNAME=admin
heroku config:set ADMIN_PASSWORD=your-secure-password-here

# Установите режим продакшена
heroku config:set FLASK_ENV=production
```

#### Шаг 4: Развертывание
```bash
# Добавьте Heroku как удаленный репозиторий
git init
git add .
git commit -m "Initial commit"

# Разверните приложение
git push heroku main

# Откройте приложение
heroku open
```

### 2. Railway (Альтернатива - бесплатно)

#### Шаг 1: Подготовка
1. Создайте аккаунт на [Railway](https://railway.app)
2. Подключите GitHub репозиторий

#### Шаг 2: Настройка
1. Создайте новый проект в Railway
2. Подключите ваш GitHub репозиторий
3. Railway автоматически определит Python приложение

#### Шаг 3: Переменные окружения
В настройках проекта добавьте:
```
SECRET_KEY=your-secret-key-here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password-here
FLASK_ENV=production
```

### 3. Render (Альтернатива - бесплатно)

#### Шаг 1: Подготовка
1. Создайте аккаунт на [Render](https://render.com)
2. Подключите GitHub репозиторий

#### Шаг 2: Создание веб-сервиса
1. Нажмите "New +" → "Web Service"
2. Подключите ваш репозиторий
3. Настройте:
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn dispatcher_app:app`

#### Шаг 3: Переменные окружения
Добавьте в Environment Variables:
```
SECRET_KEY=your-secret-key-here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password-here
FLASK_ENV=production
```

## 🔐 Настройка безопасности

### Рекомендуемые пароли
Используйте сложные пароли:
- Минимум 12 символов
- Смесь букв, цифр и специальных символов
- Пример: `Disp@tcher2024!Secure`

### Переменные окружения для продакшена
```bash
SECRET_KEY=your-very-long-random-secret-key
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-very-secure-password
FLASK_ENV=production
```

## 📱 Доступ к системе

После развертывания ваша система будет доступна по URL:
- **Heroku**: `https://your-app-name.herokuapp.com`
- **Railway**: `https://your-app-name.railway.app`
- **Render**: `https://your-app-name.onrender.com`

### Данные для входа
- **Имя пользователя**: admin (или то, что вы установили в ADMIN_USERNAME)
- **Пароль**: тот, который вы установили в ADMIN_PASSWORD

## 🔄 Обновление системы

### Heroku
```bash
git add .
git commit -m "Update system"
git push heroku main
```

### Railway/Render
Просто сделайте push в ваш GitHub репозиторий - система обновится автоматически.

## 📊 Мониторинг

### Heroku
```bash
# Просмотр логов
heroku logs --tail

# Статус приложения
heroku ps
```

### Railway
Используйте встроенную панель мониторинга в Railway Dashboard.

## 🆘 Решение проблем

### Проблема: Приложение не запускается
1. Проверьте логи: `heroku logs --tail`
2. Убедитесь, что все переменные окружения установлены
3. Проверьте, что Procfile существует

### Проблема: База данных не работает
1. Убедитесь, что PostgreSQL добавлен: `heroku addons`
2. Проверьте DATABASE_URL: `heroku config:get DATABASE_URL`

### Проблема: Не могу войти в систему
1. Проверьте переменные ADMIN_USERNAME и ADMIN_PASSWORD
2. Убедитесь, что пароль установлен правильно

## 💡 Советы

1. **Регулярно делайте бэкапы** - экспортируйте данные в Excel
2. **Используйте HTTPS** - все облачные платформы предоставляют SSL сертификаты
3. **Мониторьте использование** - следите за лимитами бесплатных планов
4. **Обновляйте пароли** - регулярно меняйте пароли администратора

## 📞 Поддержка

Если у вас возникли проблемы:
1. Проверьте логи приложения
2. Убедитесь, что все файлы загружены правильно
3. Проверьте переменные окружения
4. Обратитесь к документации выбранной платформы