using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Notification
{
    public class NotificationHistory
    {
        public int Id { get; set; }
        public int ChannelId { get; set; }
        public string ChannelName { get; set; }
        public Guid ConditionId { get; set; }
        public DateTime RaisedTime { get; set; }
        public DateTime? SentTime { get; set; }
        public string Message { get; set; }
        public string MetaData { get; set; }
        public bool IsRead { get; set; }
    }
}
