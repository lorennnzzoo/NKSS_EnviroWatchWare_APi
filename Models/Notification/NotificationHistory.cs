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
        public int StationId { get; set; }
        public string ChannelName { get; set; }
        public string StationName { get; set; }
        public Guid ConditionId { get; set; }
        public string ConditionType { get; set; }
        public DateTime RaisedTime { get; set; }
        public DateTime? EmailSentTime { get; set; }
        public string SentEmailAddresses { get; set; }
        public DateTime? MobileSentTime { get; set; }
        public string SentMobileAddresses { get; set; }
        public string Message { get; set; }
        public string MetaData { get; set; }
        public bool IsRead { get; set; }
    }
}
