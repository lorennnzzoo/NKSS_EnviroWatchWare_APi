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
        private readonly NotificationService notificationService;
        public NotificationHistoryService(INotificationHistoryRepository _notificationHistoryRepository, NotificationService _notificationService)
        {
            notificationHistoryRepository = _notificationHistoryRepository;
            notificationService = _notificationService;
        }
        public IEnumerable<NotificationHistory> GetAllNotifications()
        {
            var rawHistory = notificationHistoryRepository.GetAllNotifications();            
            return rawHistory;
        }       

        public void ReadNotification(int notificationId)
        {
            notificationHistoryRepository.ReadNotification(notificationId);
        }
    }
}
