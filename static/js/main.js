// Основные функции для мессенджера-планировщика

// Глобальные переменные
let socket = null;
let currentUser = null;

// Инициализация приложения
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

function initializeApp() {
    // Инициализация WebSocket соединения
    if (typeof io !== 'undefined') {
        socket = io();
        setupSocketEvents();
    }
    
    // Инициализация общих функций
    setupCommonFunctions();
    
    // Инициализация уведомлений
    setupNotifications();
}

// Настройка WebSocket событий
function setupSocketEvents() {
    if (!socket) return;
    
    socket.on('connect', function() {
        console.log('Подключено к серверу');
        updateConnectionStatus(true);
    });
    
    socket.on('disconnect', function() {
        console.log('Отключено от сервера');
        updateConnectionStatus(false);
    });
    
    socket.on('error', function(error) {
        console.error('Ошибка WebSocket:', error);
        showNotification('Ошибка соединения', 'error');
    });
}

// Обновление статуса соединения
function updateConnectionStatus(isConnected) {
    const statusElement = document.getElementById('connectionStatus');
    if (statusElement) {
        statusElement.textContent = isConnected ? 'Онлайн' : 'Офлайн';
        statusElement.className = isConnected ? 'badge bg-success' : 'badge bg-danger';
    }
}

// Настройка общих функций
function setupCommonFunctions() {
    // Автоматическое скрытие уведомлений
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach(alert => {
        setTimeout(() => {
            const bsAlert = new bootstrap.Alert(alert);
            bsAlert.close();
        }, 5000);
    });
    
    // Подтверждение удаления
    const deleteButtons = document.querySelectorAll('[data-confirm]');
    deleteButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            const message = this.getAttribute('data-confirm');
            if (!confirm(message)) {
                e.preventDefault();
            }
        });
    });
}

// Система уведомлений
function setupNotifications() {
    // Создание контейнера для уведомлений
    if (!document.getElementById('notificationContainer')) {
        const container = document.createElement('div');
        container.id = 'notificationContainer';
        container.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 9999;
            max-width: 400px;
        `;
        document.body.appendChild(container);
    }
}

// Показать уведомление
function showNotification(message, type = 'info', duration = 5000) {
    const container = document.getElementById('notificationContainer');
    if (!container) return;
    
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    container.appendChild(notification);
    
    // Автоматическое удаление
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, duration);
    
    // Анимация появления
    setTimeout(() => {
        notification.classList.add('show');
    }, 100);
}

// Функции для работы с задачами
const TaskManager = {
    // Создание задачи
    create: function(data) {
        return fetch('/create_task', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data)
        })
        .then(response => response.json());
    },
    
    // Обновление статуса задачи
    updateStatus: function(taskId, status) {
        return fetch(`/task/${taskId}/status`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ status: status })
        })
        .then(response => response.json());
    },
    
    // Удаление задачи
    delete: function(taskId) {
        return fetch(`/task/${taskId}`, {
            method: 'DELETE'
        })
        .then(response => response.json());
    }
};

// Функции для работы с чатом
const ChatManager = {
    // Отправка сообщения
    sendMessage: function(room, message) {
        if (socket) {
            socket.emit('message', { room: room, message: message });
        }
    },
    
    // Присоединение к комнате
    joinRoom: function(room) {
        if (socket) {
            socket.emit('join', { room: room });
        }
    },
    
    // Покидание комнаты
    leaveRoom: function(room) {
        if (socket) {
            socket.emit('leave', { room: room });
        }
    }
};

// Утилиты
const Utils = {
    // Форматирование даты
    formatDate: function(date) {
        return new Date(date).toLocaleDateString('ru-RU', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
    },
    
    // Форматирование времени
    formatTime: function(date) {
        return new Date(date).toLocaleTimeString('ru-RU', {
            hour: '2-digit',
            minute: '2-digit'
        });
    },
    
    // Проверка валидности email
    isValidEmail: function(email) {
        const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    },
    
    // Генерация случайного ID
    generateId: function() {
        return Math.random().toString(36).substr(2, 9);
    },
    
    // Дебаунс функция
    debounce: function(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
};

// Обработка ошибок
window.addEventListener('error', function(e) {
    console.error('Глобальная ошибка:', e.error);
    showNotification('Произошла ошибка. Попробуйте обновить страницу.', 'danger');
});

// Обработка необработанных промисов
window.addEventListener('unhandledrejection', function(e) {
    console.error('Необработанная ошибка промиса:', e.reason);
    showNotification('Произошла ошибка сети. Проверьте соединение.', 'warning');
});

// Экспорт функций для использования в других модулях
window.MessengerPlanner = {
    TaskManager,
    ChatManager,
    Utils,
    showNotification,
    socket
};
