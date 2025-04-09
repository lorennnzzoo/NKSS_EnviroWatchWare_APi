using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface INotificationHistoryService
    {
        IEnumerable<Models.Notification.NotificationHistory> GetAllNotifications();        
        void ReadNotification(int notificationId);
    }
}
