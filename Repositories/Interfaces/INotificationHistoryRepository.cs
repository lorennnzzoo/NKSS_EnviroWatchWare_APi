using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface INotificationHistoryRepository
    {
        IEnumerable<Models.Notification.NotificationHistory> GetUnreadNotifications();
        IEnumerable<Models.Notification.NotificationHistory> GetAllNotifications();
        void ReadNotification(int notificaitonId);
    }
}
