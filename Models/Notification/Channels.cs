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
    public enum ConditionType
    {
        Value=0,
        LogTime=1
    }
    public enum OperatorType
    {
        GreaterThan=0,    // >
        LessThan=1,       // <
        Equal=2,          // =
        GreaterThanOrEqual=3, // >=
        LessThanOrEqual=4  // <=
    }
    public class Condition
    {
        public string ConditionName { get; set; }
        public ConditionType ConditionType { get; set; }
        public int Cooldown { get; set; }  
        public int Duration { get; set; }
        public OperatorType Operator { get; set; }
        public double Threshold { get; set; }
    }


    public class SubscribeRequest
    {
        public int ChannelId { get; set; }
        public List<Models.Notification.Condition> Conditions { get; set; }
    }
}
