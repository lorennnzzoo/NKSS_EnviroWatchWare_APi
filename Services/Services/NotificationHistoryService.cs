using Models.Notification;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class NotificationHistoryService : INotificationHistoryService
    {
        private readonly INotificationHistoryRepository notificationHistoryRepository;
        public NotificationHistoryService(INotificationHistoryRepository _notificationHistoryRepository)
        {
            notificationHistoryRepository = _notificationHistoryRepository;
        }
        public IEnumerable<NotificationHistory> GetAllNotifications()
        {
            return notificationHistoryRepository.GetAllNotifications();
        }

        public IEnumerable<NotificationHistory> GetUnreadNotifications()
        {
            return notificationHistoryRepository.GetUnreadNotifications();
        }

        public void ReadNotification(int notificationId)
        {
            notificationHistoryRepository.ReadNotification(notificationId);
        }
    }
}
