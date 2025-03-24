using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Notification
{
    public class ChannelStatus
    {
        public int ChannelId { get; set; }
        public string ChannelName { get; set; }
        public string StationName { get; set; }
        public string Units { get; set; }
        public bool Subscribed { get; set; }
    }

    public class NotificationSubscription
    {
        public int ChannelId { get; set; }
        public List<Condition> Conditions { get; set; } = new List<Condition>();
    }

    public class Condition
    {
        public ConditionType Type { get; set; }  // Enum for condition type
        public int Cooldown { get; set; }  // Cooldown in minutes
    }

    public enum ConditionType
    {
        Offline,
        Exceedance
    }

}
